# Lucky Reverse Proxy Notes

This project can be published in two ways:

1. Use Lucky path routing directly
2. Put an extra Nginx container in front of frontend and backend

For the current NAS setup, Lucky direct routing is enough.

## Container ports

- Frontend: `http://192.168.0.5:8071`
- Backend: `http://192.168.0.5:8083`
- Optional Nginx entrypoint: `http://192.168.0.5:6606`

## Lucky routing that works

The final working rules on port `6606` are:

- `cms-api`
  - Frontend address: `cms.zglweb.cn/api`
  - Backend address: `http://192.168.0.5:8083/api`
- `cms-uploads`
  - Frontend address: `cms.zglweb.cn/uploads`
  - Backend address: `http://192.168.0.5:8083/uploads`
- `cms`
  - Frontend address: `cms.zglweb.cn`
  - Backend address: `http://192.168.0.5:8071`

Rule order matters:

1. `cms-api`
2. `cms-uploads`
3. `cms`

## Why this is necessary

Lucky strips the matched prefix when forwarding requests.

Example:

- External request: `/api/auth/login`
- If backend target is `http://192.168.0.5:8083`
- Lucky forwards to: `http://192.168.0.5:8083/auth/login`
- This is wrong because the backend expects `/api/auth/login`

So the backend targets must include the prefix:

- `/api` rule -> backend target ends with `/api`
- `/uploads` rule -> backend target ends with `/uploads`

## Symptom of wrong routing

If Lucky strips `/api` but the backend target does not include `/api`, iOS may show:

- login succeeds
- then file preview says session expired
- browser visit to `/api/auth/me` returns a backend error or wrong route

## Quick verification

After Lucky is configured, these checks should pass:

1. `https://cms.zglweb.cn:6606/` opens the frontend
2. `https://cms.zglweb.cn:6606/api/auth/me` reaches backend
3. Lucky logs show target URLs with `/api/...` preserved

Correct log example:

- incoming: `/api/auth/login`
- target: `http://192.168.0.5:8083/api/auth/login`

## Recommended Lucky options

- `Use target host header`: enable
- `HttpClient timeout`: `120` or above
- `Basic auth`: disable
- `Web auth`: disable
- `WAF`: none

## iOS note

No iOS rollback is needed for this issue.

The iOS client now keeps two safe fallbacks:

- If `If-None-Match` gets `401`, it falls back to normal download
- If `Range` request gets `401`, it retries one full download

These changes improve compatibility with proxies and should stay.
