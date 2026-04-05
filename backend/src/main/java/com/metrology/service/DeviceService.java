package com.metrology.service;

import com.metrology.dto.DashboardStats;
import com.metrology.dto.DeviceDto;
import com.metrology.dto.PageResult;
import com.metrology.entity.Department;
import com.metrology.entity.Device;
import com.metrology.entity.UserSettings;
import com.metrology.entity.User;
import com.metrology.repository.DepartmentRepository;
import com.metrology.repository.DeviceRepository;
import com.metrology.repository.UserRepository;
import com.metrology.repository.UserSettingsRepository;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import org.apache.poi.ss.usermodel.DateUtil;
import java.io.*;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DeviceService {

    private final DeviceRepository deviceRepository;
    private final DepartmentRepository departmentRepository;
    private final UserRepository userRepository;
    private final UserSettingsRepository settingsRepository;

    @Value("${upload.path:/app/uploads}")
    private String uploadPath;
    private static final String DEPT_SEPARATOR = ",";

    UserSettings getSettings(String username) {
        return userRepository.findByUsername(username)
                .flatMap(u -> settingsRepository.findByUserId(u.getId()))
                .orElseGet(() -> {
                    UserSettings s = new UserSettings();
                    s.setWarningDays(315);
                    s.setExpiredDays(360);
                    return s;
                });
    }

    private boolean canViewPurchasePrice(String username) {
        return userRepository.findByUsername(username)
                .map(u -> "ADMIN".equals(u.getRole()))
                .orElse(false);
    }

    /** 闂傚倸鍊搁崐鎼佸磹閹间礁纾归柟闂寸绾惧綊鏌熼梻瀵割槮缁炬儳缍婇弻锝夊箣閿濆憛鎾绘煕閵堝懎顏柡灞剧洴椤㈡洟鏁愰崱娆欑穿闂備線鈧偛鑻晶鍓х磼閻樿櫕灏柣锝夋敱缁虹晫绮欏▎鐐秱闂備胶鍋ㄩ崕閬嶅疮鐠恒劏濮抽柕澶嗘櫆閳锋帒霉閿濆浂鐒炬い銉ョ箻閺屾稓鈧絺鏅濈粣鏃傗偓瑙勬礃濞叉ê顭囪箛娑樼厸闁告劦浜為崝璺衡攽閻橆喖鐏遍柛鈺傜墵瀹曟繈寮介鐔蜂簵濠电偛妫欓幐鍝ョ棯瑜旈弻娑㈩敃閿濆洨鐣甸梺鎶芥敱濡啴寮婚敐澶嬫櫜濠㈣泛顦伴崰姘攽椤旂》宸ユい顓炲槻閻ｇ兘骞掑Δ鈧洿闂佸憡渚楅崹顖炴偨閼姐倗纾介柛灞剧懆閸忓瞼绱掗鍛仯缂侇喗鐟╅獮瀣晜缂佹ɑ娅撻梻濠庡亜濞诧附绗熷Δ鍛瀬濠电姴娲﹂悡鐘测攽椤旇棄濮囬柍褜鍓氶〃鍛村煝閺冨倹宕夐柕濞у拑绱抽梻浣侯焾閺堫剟鎮烽妸鈺婃晩濠㈣埖鍔栭悡鏇㈡倵閿濆骸浜濈€规洖鐭傞弻锛勪沪閸撗勫垱闂佺硶鏅涚€氭澘鐣峰Δ鍛亹闁告繂瀚Ч妤呮⒑閻熸壆鐣柛銊ㄦ閻ｇ兘宕￠悙鈺傤潔濠电偛妫欓崹鐢垫暜妤ｅ啯鈷掑ù锝囶焾椤ュ繘鏌涚€ｎ亝鍣介柟骞垮灲瀹曟﹢顢欐總鍛婏紬闂佽崵鍠愰悷銉р偓姘ュ妽缁傚秴顭ㄩ崼銏犲絼闂佹悶鍎滅仦钘夊闂備礁鎲″Λ鎴犵不閹捐钃熼柨娑樺濞岊亪鏌ｉ敐鍛健闁靛璐熸禍婊呮喐瀹€鈧▎銏狀潩鐠洪缚鎽曞┑鐐村灟閸ㄥ湱绮绘繝姘€甸梻鍫熺⊕閸熺偤鏌涢敐鍕祮闁诡喗顨堥幉鎾礋椤掆偓椤︹晠姊洪幖鐐插闁绘牕銈搁幃浼搭敊绾拌鲸寤洪梺閫炲苯澧撮柕鍡曠閳诲酣骞樺畷鍥舵Н闂備礁鍚嬬粊鎾棘娓氣偓瀹曟垿骞樺ú缁樻櫌闂佸憡娲﹂崜娆撳焵椤掆偓閻忔岸銆冮妷鈺傚€烽柤纰卞厸閾忓酣姊洪崨濠冣拹缁炬澘绉规俊鐢稿礋椤栨稒娅嗛柣鐘叉穿鐏忔瑦绂掗幖浣光拺闁告繂瀚€氱増銇勯幋婵愭Ц闁伙絿鍏樺畷濂稿即閻愬秮鏅濋幉姝岀疀濞戞瑥鍓ㄩ梺鍓插亞閸犳挾寮ч埀顒勬⒑濮瑰洤鐏叉繛浣冲啰鎽ラ梻鍌欒兌椤牓鏁冮妶鍥╃濠电姴鍊婚弳锕傛煟閵忋埄鐒鹃柣鎺戠仛閵囧嫰骞掗幋婵冨亾閼姐倕顥氶柦妯侯棦瑜版帗鏅查柛顐ゅ櫏娴犫晠鏌ｉ姀鈺佺仭闁烩晩鍨跺璇测槈閵忕姈鈺呮煏婢诡垰鍊藉鍛婁繆閻愵亜鈧倝宕戦崟顓熷床闁归偊鍠栧鍙変繆閻愵亜鈧洜鎹㈤幇顔瑰亾濮橀棿绨芥俊鍙夊姍瀹曞ジ寮撮悢鍙夊闂備礁鎲＄粙鎴︽晝閵夛箑绶為柛鏇ㄥ灡閻撴洘淇婇婵嗗惞闁活厼锕ラ妵鍕敇濠婂啫顫囬悗瑙勬礀閵堟悂骞冮姀銈呬紶闁告洦鍋嗛悷鏌ユ⒒娴ｈ棄鍚归柛鐘冲姉閸掓帒顓奸崶褍鐏婇梺瑙勫劤绾绢參寮抽敂鐣岀瘈濠电姴鍊搁弳濠囨煛鐎ｎ亪鍙勯柡宀€鍠栭獮鍡氼槾闁挎稑绉归弻锛勪沪閻ｅ苯鈪靛┑顔硷攻濡炶棄鐣峰鍫熷殤妞ゆ巻鍋撻悽顖樺劦濮婃椽宕妷銉愶綁鎮介妞诲亾閹颁礁娈ㄧ紓浣割儐椤戞瑩宕ョ€ｎ喗鐓曢柍鈺佸暟閹冲懏銇勯弮鈧ú鐔奉潖閾忕懓瀵查柡鍥╁仜閳峰姊洪幐搴″摵闁哄矉缍€缁犳稒绻濋崘鈺冨絿闂備焦鐪归崕鐑樼椤忓牏宓侀柛鈩冨嚬濡插綊姊虹粙娆惧剭闁搞劋绮欏濠氬灳瀹曞洦娈曢柣搴秵閸撴瑩宕哄畝鍕拺閻庡湱濯崵娆愭叏濮楀牆顩紒顔款嚙閳藉濮€閻樻剚妫熼梻浣告贡椤牏鈧灚甯楃粋鎺撴綇閳哄啰锛濋梺绋挎湰閻熴劑宕楀畝鍕厱閻庯綆鍋呭畷宀€鈧娲樺ú鐔风暦濡警鍟呮い鏃€鍎虫慨娲⒒娴ｈ姤纭堕柛鐘虫尰閹便劑骞橀钘夌彅闂佺粯鏌ㄩ崥瀣偂閻斿吋鐓涢柛鎰╁妼閳ь剛鏁婚獮蹇涙晸閻樺磭鍘告繛杈剧秮濞煎宕濋悢鍏肩厽闁靛鍠曢柇顖涖亜閵忊槄鑰块柟顔规櫅閻ｇ兘宕惰铦庨梻鍌氬€风粈渚€骞夐敓鐘茬鐟滅増甯掔壕濠氭煕濞戝崬鐏＄€规洖寮剁换婵嬫濞戞艾顣洪梺鍝勵儏閻楀﹥绌辨繝鍥舵晬婵﹩鍓氫簺濠电偛鐡ㄧ划灞炬櫠娴犲鐒垫い鎺戝枤濞兼劖绻涢崣澶屽ⅹ閻撱倝鏌ㄩ弴鐐测偓鍝ョ不閻斿皝鏀介柛灞剧閸熺偤鏌嶉柨瀣伌闁哄矉缍侀幃銏ゅ川婵犲嫬鍤掓繝纰樺墲瑜板啴鈥﹂悜钘夎摕闁绘柨鍚嬮幆鐐淬亜閹般劌浜惧銈呯箰閻楀﹪宕戦埡鍐ｅ亾閻熸澘顏柛瀣躬閹繝濡烽埡鍌滃幈濡炪倖鍔х徊璺ㄧ不濡眹浜滈柡鍌濇硶閻掑憡鎱ㄦ繝鍐┿仢鐎规洜鍏橀、姗€鎮欓幓鎺濈€遍梻鍌欒兌閹虫捇鎯冮悜钘夌柧闁绘灏欓弳锔姐亜閺嶃劍鐨戦柡鍡楁閺屾盯寮撮妸銉ュ箣闂佺懓鍢查…宄邦潖閾忓湱鐭欓柟绋垮閹烽亶姊洪懡銈呮殌闁搞儰绀佸ú顓㈠极閸愵喖纾兼繛鎴炶壘楠炲秹姊洪懡銈呅㈡繛澹洤宸濇い鏍ㄧ矋椤矂姊虹拠鍙夊攭妞ゎ偄顦叅闁哄稁鍋嗙粈濠傗攽閻樺弶鎼愮紒鐘崇墵閺屽秹鍩℃担鍛婃闂佺娴烽崰鎰┍婵犲浂鏁嶆繝闈涙閹偤姊洪柅鐐茶嫰婢ь垱淇婇悙鑸殿棄妞ゎ偄绻愮叅妞ゅ繐瀚鍥煙閼圭増褰х紒鎻掓健閹箖妫冨☉杈ㄥ瘜闂侀潧鐗嗙换鎺旀娴煎瓨鐓曟俊銈傚亾闁哥喎娼￠幃楣冩倻閽樺顓洪梺鎸庢磵閸嬫捇宕剁€涙绡€闁靛骏绲剧涵鐐亜閹存繃鍠樼€规洏鍨介幃浠嬪川婵犲嫬骞楅梺纭呭閹活亞寰婃ィ鍐ㄦ辈闁冲搫鍊舵禍婊勩亜閹捐泛浠у褎绋撶槐鎺楀磼濞戞ɑ璇為梺杞扮閸熸挳宕洪埀顒併亜閹烘垵顏╅柣鎾达耿閺岀喐娼忛幆褏妲ｉ梺杞扮缁夌數鎹㈠☉銏犵闁绘劕鐏氶崳褔姊洪崫銉ヤ粶妞わ箓娼ч～蹇涙惞鐟欏嫬鐝伴梺鐐藉劥濞呮洟鎮橀崼銏㈢＝闁稿本姘ㄥ瓭闂佹寧娲︽禍顏堝箖娴兼惌鏁婇柣锝呯灱閹虫繈姊洪柅鐐茶嫰婢ф挳鏌ｅ☉鍗炴珝妤犵偞甯掕灃闁逞屽墰缁鏁愰崱娆戠槇闂佸壊鐓堥崑鍕叏婢舵劖鐓冪憸婊堝礈濮樿泛绠伴柛鎰▕濞兼牜绱撴担鑲℃垶鍒婇幘顔界厱婵炴垶锕弨濠氭煕鎼淬垺灏柍瑙勫灴閸┿儵宕卞鍓у嚬婵＄偑鍊戦崝宀勬偋閹捐崵宓侀柟杈剧畱椤懘鏌ｅ▎灞戒壕濠电偟顑曢崝鎴﹀蓟瀹ュ牜妾ㄩ梺鍛婃尰閻熲晠銆?*/
    public List<DeviceDto> getDevices(String username, String search, String assetNo, String serialNo,
                                       String dept, String validity, String responsiblePerson, String useStatus) {
        UserSettings settings = getSettings(username);
        boolean canSeePurchasePrice = canViewPurchasePrice(username);

        // 闂傚倸鍊搁崐鎼佸磹閹间礁纾归柟闂寸绾惧綊鏌熼梻瀵割槮缁炬儳缍婇弻鐔兼⒒鐎靛壊妲紒鐐劤缂嶅﹪寮婚悢鍏尖拻閻庨潧澹婂Σ顔剧磼閻愵剙鍔ょ紓宥咃躬瀵鎮㈤崗灏栨嫽闁诲海鏁搁…鍫熶繆娴犲鈷戠紒瀣儥閸庡繑銇勯幋婵愭█闁诡噯绻濋、鏇㈡晝閳ь剟鎮欐繝鍥ㄧ厪濠电倯鈧崑鎾翠繆閹绘帞澧㈢紒杈ㄥ浮閹瑩顢楅埀顒勫礉閵堝棎浜滄い鎾跺Т閸樺鈧鍠栭…鐑藉极閹邦厼绶炲┑鐘插濞煎姊绘担渚劸闁哄牜鍓熼妴鍐幢濞嗗苯浜炬慨姗嗗幘濞插瓨鎱ㄦ繝鍕妺婵炵⒈浜獮宥夘敋閸涱啩婊勭節閻㈤潧浠滄俊顖氾躬瀹曪綁宕橀…鎴濇婵犵數濮电喊宥夊磻閸曨垱鐓曢煫鍥ㄦ尵濮ｇ偤鏌熷畡閭︾吋闁哄矉绲鹃幆鏃堟晲閸℃ɑ鐦庢俊鐐€ら崢濂告偋婵犲啰鈹嶅┑鐘插暟椤╃兘鎮楅敐搴′簮闁圭柉娅ｇ槐鎾存媴閸撴彃鍓卞銈嗗灦閻熲晛鐣烽弴銏犵婵犻潧鍟弬鈧梻浣虹帛閸斿繘寮插☉娆戭洸濡わ絽鍟埛鎺懨归敐鍛暈闁诡垰鐗撻弻锟犲醇椤愩垹鈷嬮梺璇″灠鐎氫即銆佸☉銏″€烽柛娆忣槹琚ｉ梻鍌欑閹测€趁洪敃鍌氬瀭闁规鍠氶惌鍡涙煕閹伴潧鏋熼柣鎾跺枛閺岀喐瀵肩€涙ɑ閿繝鈷€鍌氬祮闁哄矉绻濆畷閬嶎敇閻樺灚娈兼繝娈垮枛閿曪妇鍒掗鐐茬闁告稒娼欏婵嗏攽閻樻彃鏆欓柡瀣灥閳规垿鎮╅幇浣告櫛闂佸摜濮甸〃濠囩嵁閹版澘绠柣锝呰嫰缁侊附绻濋悽闈浶㈤柛鐕佸灦瀹曟洟鎮㈤崗鑲╁帾婵犵數鍋涢悘婵嬪礉閵堝鐓曟繛鍡楄嫰娴滄儳鈹戦悩鍨毄濠殿喕鍗冲畷瑙勭附缁嬫寧妲梺鍝勭▉閸樿偐绮堟径鎰厸闁搞儮鏅涘暩婵炴垶鎸哥粔鎾煘閹达附鍋愮€规洖娴傞弳锟犳⒑缁嬪尅宸ラ柣蹇旀皑閹广垹鈽夐姀鐘殿吅闂佺粯鍔曢悘姘跺吹閸屾稓绠鹃柟鎯ь嚟椤ｈ尙绱掔€ｎ偄娴鐐茬墦婵℃悂鏁傞崜褏妲囬梻浣侯焾閺堫剛鍒掗崼銉︽優閹肩补妲呭〒濠氭煏閸繄鍑圭紒銊ヮ煼閺屾盯鎮㈡搴㈡喖婵烇絽娲ら敃顏勭暦婵傜鍗抽柣鎰蔼閳ь剙鐏濋埞鎴﹀煡閸℃浠搁梺琛″亾閺夊牃鏂侀崑鎾愁潩鏉堚晛绗＄紓浣虹帛缁诲牓骞冩禒瀣棃婵炴垶顨堥幑鏇㈡煟鎼淬埄鍟忛柛鐘崇墬閺呰埖鎯旈妸銉ь槴闂佸湱鍎ら幐濠氬磿閻斿吋鐓冩い鎾寸矊閸旂數绱撳鍕獢闁绘侗鍣ｅ畷鍫曨敆閳ь剛鐥閹綊骞侀幒鎴濐瀷濠电偟鍘чˇ闈涱潖缂佹ɑ濯寸紒瀣儥濡矂姊虹粙娆惧剱閻㈩垪鈧磭鏆﹂柟杈剧畱瀹告繈鏌℃径瀣仼闁哄睙鍥ㄢ拺闁告劕寮堕幆鍫ユ煙閸愯尙绠婚柛鈺傜洴楠炲鏁傞悾灞藉箺闂備浇顫夐崕鎶藉疮閸ф鍎婇柕濠忓缁犻箖鏌ゅù瀣珔闁哄鐩弻锛勪沪閸撗€濮囩紓浣虹帛缁诲牆鐣峰鈧崺锟犲礃閻愵儷褔姊虹拠鎻掝劉妞ゆ梹鐗犲畷鏉课旈崨顔间簵闂佽法鍠撴慨鎾及閵夆晜鐓ラ柣鏂挎惈瀛濋悗鐟版啞缁诲啴濡甸崟顖氱睄闁搞儴鍩栫紞鍫ユ煟鎼搭澀浜㈡俊顐㈠閸╃偤骞嬮敂钘夆偓鐑芥倵濞戞顏堟瀹ュ鈷戦柤褰掑亰濞兼劙鏌涙惔锛勶紞闁告瑥鎳樺娲濞戞艾顣哄銈忓瘜閸ㄨ泛鐣峰▎鎾村亹缂備焦顭囬崢鎼佹⒑閸涘﹤濮傞柛鏂垮閺呰泛鈽夐姀锛勫幗闂佽鍎抽悺銊х矆鐎ｎ喗鐓涚€光偓鐎ｎ剛鐦堥悗瑙勬礃閿曘垽寮幇鏉垮窛妞ゆ巻鍋撴い銉﹀哺濮婂宕掑▎鎴濆闂佽鍠栭悥鐓庣暦濠靛牃鍋撻敐搴″缂佽翰鍊曢埞鎴︽偐瀹曞浂鏆￠梺绋匡工閻栧ジ骞冨Δ鍛櫜閹煎瓨绻冮崰姘攽閻愬瓨灏い顓犲厴瀵寮撮姀鐘诲敹濠电娀娼уù鍌毼涢悙鐢电＝濞达綀顕栧▓鏇㈡偨椤栥倗绡€妤犵偛鍟灃闁逞屽墴閿濈偛鈹戠€ｎ偄浜楅柟鑹版彧缁辨洟鎯堥崟顖涚厽閹兼番鍊ゅ鎰箾閸欏顏嗗弲闂佸搫绋侀崣搴ㄥ极閸ヮ剚鐓曢煫鍥ㄦ礀鐢墎绱掗崜浣镐槐闁诡喗顨婇弫鎰償閳ユ剚娼绘俊銈囧Х閸嬫盯鎮ч幘鎰佹綎缂備焦蓱婵挳鏌涘☉姗堟敾闁稿孩鎸搁埞鎴︽倷閼碱剚鍕鹃梺鎼炲姀濡嫰鎮惧畡鎵虫斀闁糕剝鐟﹀▓鏇㈡⒑閸涘﹥澶勯柛妯垮亹缁﹪鏁冮埀顒勫煘閹寸偛绠犻梺绋匡攻濞茬喖鐛繝鍛杸婵炴垶鐟ユ禍妤€鈹戦悙鏉戠仧闁搞劍妞介幃锟犲即閵忥紕鍘撻梺瀹犳〃缁€渚€寮搁妶鍡欑闁割偆鍣ラ悞鐣岀磼鏉堛劌娴柟顔规櫅椤斿繘顢欓幆褎鍊梻鍌欑閹碱偅寰勯崶顒€鐒垫い鎺嗗亾缁剧虎鍙冨鎶藉幢濞戞瑧鍘撻悷婊勭矒瀹曟粓鎮㈡搴㈡婵炴潙鍚嬪娆撳礃閳ь剟鎮峰鍕煉鐎规洜鏁诲鎾閿涘嫬骞堟俊鐐€栭崝褏寰婇崜褏鐭嗛柍褜鍓涚槐鎾存媴閸濆嫷鈧挾绱掗幓鎺戔挃闁瑰箍鍨归埞鎴犫偓锝庡亽濡啫鈹戦悙鏉戠仸闁荤啙鍥ч柍鍝勬噺閳锋垿鏌涘┑鍕姎濞存粌銈搁弻娑㈠棘閹稿孩宕冲┑鈥冲级閸旀瑩鐛Ο鍏煎珰闁肩⒈鍓ㄧ槐鍙夌節閻㈤潧浠滄俊顐ｇ懇瀹曟繂螖閸涱厙褔鏌ｅΔ鈧悧鍛崲閸℃稒鐓熼柟閭﹀墰閹界姷绱撳鍡楃伌闁哄瞼鍠栭幊鐐哄Ψ瑜忛悡澶娢旈悩闈涗沪闁搞劍瀵ч幈銊╁焵椤掑嫭鐓忛柛顐ｇ箖閸ｄ粙鏌ㄥ☉娆戠煉婵﹨娅ｇ槐鎺懳熼搹閫涙樊婵犵妲呴崑鍛存偡閳轰緡鍤曢柡灞诲労閺佸倿鏌涢銈呮毐闁归攱妞藉娲捶椤撗呭姼濠电偞鎸抽ˉ鎾跺垝婵犳艾绠绘繛锝庡厸缁ㄥ姊洪幐搴㈩梿妞ゆ泦鍥ㄥ€堕柨鐔哄У閸婄敻姊婚崼鐔衡棨闁稿鍨介弻鐔碱敊鐟欏嫭鐝栫紓浣介哺鐢帟鐏掗梺缁樻尭妤犲摜绮婚悙鐑樷拻闁稿本鐟чˇ锕傛煙绾板崬浜滈悡銈夋煏韫囧鈧洜绮堟径鎰€堕柣鎰絻閳锋梹銇勯埡鍌滃弨闁哄矉缍侀獮鍥敊閻撳骸顬嗛梻浣虹帛閹歌煤濮椻偓楠炲牓濡搁妷搴㈡閸┾偓妞ゆ巻鍋撻摶鐐翠繆閵堝嫮鍔嶆繛鍛█閹鈽夊▍铏灴瀹曪綀绠涢幘顖涙杸闂佺粯蓱瑜板啴寮抽悙鐑樼厪闁搞儯鍔庣粻姗€鏌嶈閸撴繈锝炴径濞掗缚绠涘☉妯碱槷閻庡箍鍎卞ú锕€鐣烽崣澶岀瘈闂傚牊渚楅崕蹇曠磼閳ь剛鈧綆鍋佹禍婊堟煙閸濆嫭顥滃ù婊勫劤閳规垿鎮欓崣澶婃殎闂佸憡鍔х徊楣冨棘閳ь剟姊绘担铏瑰笡闁告梹顭囨禍绋库枎閹惧磭顔戦梺缁橆焽閺佸摜澹曢崗绗轰簻闁哄倽锟ラ崑銏ゆ煕濞嗗繐顏柍褜鍓濋～澶娒哄鈧畷褰掓偨缁嬭法鍙€婵犮垼鍩栭崝鏇綖閸涘瓨鐓冮柍杞扮閺嗙偤鏌ｅ┑鍥╁⒌婵﹦绮粭鐔煎焵椤掆偓椤洩顦撮柟骞垮灲瀹曞ジ濡烽妷褝绱梻浣告惈濞层劑宕曢幇鏉跨柈闁告侗鍠氱弧鈧梻鍌氱墛娓氭宕曢幇鐗堢厽闁规儳顕埥澶嬨亜椤撯剝纭堕柟鐟板缁楃喖顢涘顒€顥嶉梻鍌欐祰椤曆呮崲閸儱纾块柣銏㈩焾閽冪喖鏌ㄥ┑鍡樺櫝闁衡偓娴犲鐓曢柕鍫濇噹椤ュ繐霉濠婂簼閭柛銊╃畺瀵噣宕煎┑鍫О婵＄偑鍊栭弻銊ノｉ崼锝庢▌闂佸搫鏈惄顖炲春閸曨垰绀冮柣鎰靛墰閺嗩參姊绘担钘夊惞闁哥姴妫濆畷婵嬪箣閿曗偓閽冪喖鏌ㄥ┑鍡橆棡闁稿海鍠栭弻鏇＄疀閺囩倫銏℃叏閿濆懐澧︽慨濠冩そ瀹曘劍绻濋崘銊︽闂備礁鎽滄慨鎾煀閿濆绠栭柟顖嗗懏娈濋梺閫涚祷濞呮洟寮埀顒勬⒑鐠囨彃鍤辩紓宥呮閸┾偓妞ゆ帒顦獮鎴︽煕閺冣偓閸ㄥ灝顕ｇ拠宸悑濠㈣泛锕ｇ槐鍫曟⒑閸涘﹥澶勯柛瀣у亾闂佺顑嗛幑鍥箖閻ｅ瞼鐭欓悹渚厛閸?        String effectiveDept = dept;
        Set<String> requestedDeptScope = resolveDeptScope(dept);
        Optional<User> userOpt = userRepository.findByUsername(username);
        boolean isAdmin = userOpt.map(u -> "ADMIN".equals(u.getRole())).orElse(false);
        Set<String> deptScope = requestedDeptScope;
        boolean hasDeptConstraint = !requestedDeptScope.isEmpty();
        if (!isAdmin && userOpt.isPresent()) {
            Set<String> userDeptScope = resolveDeptScope(userOpt.get().getDepartment());
            if (!userDeptScope.isEmpty()) {
                hasDeptConstraint = true;
                deptScope = requestedDeptScope.isEmpty()
                        ? userDeptScope
                        : intersectScopes(userDeptScope, requestedDeptScope);
            }
        }
        String exactDept = hasDeptConstraint && deptScope.size() == 1 ? deptScope.iterator().next() : null;

        List<Device> devices = deviceRepository.findWithFilters(
                (search == null || search.isBlank()) ? null : search,
                (assetNo == null || assetNo.isBlank()) ? null : assetNo,
                (serialNo == null || serialNo.isBlank()) ? null : serialNo,
                exactDept,
                null,
                (useStatus == null || useStatus.isBlank()) ? null : useStatus
        );
        List<DeviceDto> result = new ArrayList<>();
        for (Device d : devices) {
            DeviceDto dto = toDto(d, settings, canSeePurchasePrice);
            boolean deptMatch = !hasDeptConstraint
                    || (dto.getDept() != null && deptScope.contains(normalizeDeptName(dto.getDept())));
            boolean validityMatch = validity == null || validity.isBlank() || validity.equals(dto.getValidity());
            boolean personMatch = responsiblePerson == null || responsiblePerson.isBlank()
                    || responsiblePerson.equals(dto.getResponsiblePerson());
            if (deptMatch && validityMatch && personMatch) result.add(dto);
        }
        result.sort(
                Comparator.comparing((DeviceDto dto) -> !"\u6b63\u5e38".equals(dto.getUseStatus()))
                        .thenComparing(dto -> dto.getNextDate() != null ? dto.getNextDate() : "9999-99-99")
        );
        return result;
    }

    /** 闂傚倸鍊搁崐鎼佸磹閹间礁纾归柟闂寸绾惧綊鏌熼梻瀵割槮缁惧墽鎳撻—鍐偓锝庝簼閹癸綁鏌ｉ鐐搭棞闁靛棙甯掗～婵嬫晲閸涱剙顥氬┑掳鍊楁慨鐑藉磻濞戔懞鍥偨缁嬫寧鐎悗骞垮劚椤︻垳绮堢€ｎ偁浜滈柟鍝勭Ф閸斿秵銇勯弬鎸庡枠婵﹦绮幏鍛村川婵犲懐顢呴梻浣侯焾缁ㄦ椽宕愬┑鍡欐殾闁汇垹鎲￠弲婵嬫煃瑜滈崜鐔煎春閵夛箑绶炲┑鐐灮閸犳牠寮婚妸褉鍋撻敐搴′簼婵犮垺鍨垮缁樻媴缁涘娈梺鍛婂灩閺咁偆妲愰悙鍝勫耿婵炴垶顭囬崝锕€顪冮妶鍡楃瑨妞わ富鍨堕悰顕€骞嬮敂鐣屽幈闁瑰吋鐣崝瀣箟妤ｅ啯鐓冮柕澶樺灣閻ｇ數鈧娲滈…鍫ｇ亙婵炶揪绲介幉锟犳偪閸岀偞鈷掗柛灞捐壘閳ь剚鎮傞幃褎绻濋崟顓犵厯闂佺鎻拋锝囩礊閺嶎偀鍋撻崗澶婁壕闂侀€炲苯澧版俊鍙夊姍楠炴鈧稒锚椤庢捇姊洪崷顓犲笡閻㈩垰锕ョ粩鐔煎即閵忊檧鎷绘繛杈剧秬濞咃綁濡存繝鍥ㄧ厱闁规儳顕粻妯荤節閳ь剚鎷呴搹鍦紳婵炶揪绲块悺鏃堝吹濞嗘劒绻嗘い鎰剁悼缁犵偟鈧鍠栭…宄邦嚕閹绢喖顫呴柣妯款嚙閺佽绻濋悽闈涒枅婵炰匠鍏犳椽濡堕崨顏呯€洪梺鎸庣箓閹峰銆掓繝姘厪闁割偅绻冮崳鐣岀磼閻橀潧浠遍柡灞剧⊕閹棃鏁愰崱妯荤槗闁诲孩顔栭崰娑㈩敋瑜旈、妯荤附缁嬪潡鍞跺銈嗗姧缂嶅棝鍩€椤掆偓濞差厼顫忕紒妯诲闁告稑锕ら弳鍫ユ⒑閸︻収鐒炬い顓犲厴楠炲啴鎮滈挊澶屽幐婵炶揪绲块崕銈呪枔閹屾富闁靛牆妫涙晶閬嶆煕鐎ｎ偆銆掔紒顔垮吹缁辨帒螣闂€鎰泿闂備礁鎼崐鎼佹倶濠靛绠栭柟杈鹃檮閻撶喖骞栭幖顓炴灈濠⒀勬尦閺岀喖顢欑粵瀣杹闂佺粯渚楅崳锝呯暦瑜版帩鏁婇柣鎾冲瘨濞兼稑鈹戦敍鍕杭闁稿ě鍛亾闂堟稓鐒哥€规洖缍婂畷濂稿即閻愯埖鎲伴梺璇插嚱缂嶅棝宕伴弽顓熷€峰┑鐘插暔娴滄粓鏌熼崫鍕ラ柛蹇撶焸閺屾稑鈻庤箛鏃戞闂佸疇顫夐崹鍧楀箖閳哄啰纾兼俊顖氼煼閺侇亝绻濈喊妯活潑闁稿鎳愰幑銏ゅ醇閵夛絺鍋撴笟鈧獮妯侯熆閸曨剚顥堢€规洏鍔戦、娆撳箚瑜嶇粻浼存⒒閸屾瑧顦﹂柟璇х磿閸掓帡宕奸姀銏㈢劶婵炴挻鍩冮崑鎾绘煟濞戝崬鏋涢摶鏍煕閹板吀绨介柨娑欑矌缁辨捇宕掑▎鎴濆濡炪値鍘煎ú銊у垝婵犳碍鍊锋繛鏉戭儐閺傗偓婵＄偑鍊栧濠氬箠閹惧顩插Δ锝呭暞閳锋帒霉閿濆洦鍤€妞ゆ洘绮庣槐鎺旀嫚閹绘巻鍋撳宀€浜辨繝鐢靛仦閸垶宕圭涵鍛闂傚倷绀佺紞濠囧磻婵犲洤绀傛慨妞诲亾鐎殿喓鍔嶇粋鎺斺偓锝庡亞閸樹粙姊鸿ぐ鎺戜喊闁搞劋鍗抽幆鍐倻濡偐鐦堥梺閫炲苯澧存鐐达耿椤㈡瑩鎮剧仦钘夌疄婵犵數濮烽弫鍛婃叏閹绢喖鐤柡澶嬶紩濞差亜绾ч柟瀛樻⒐閺傗偓闂備焦瀵х粙鎴犫偓姘煎弮瀵娊顢楁笟鍥啍闂佺粯鍔曞鍫曞窗濡眹浜滈柕蹇ョ磿閹冲洭鏌熼鈧弨閬嶆晬閹邦厽濯撮柛鎾冲级椤ワ繝姊婚崒姘偓鎼佸磹閹间礁纾归柟闂寸劍閸嬪鈹戦悩鎻掝伀闁活厽鐟╅弻鐔兼倻濮楀棙鐣堕梺姹囧€ら崳锝夊蓟閿濆绠涙い鏃傚帶婵℃椽姊虹粙鍖″伐闁诲繑宀搁獮鍫ュΩ閵夘喗寤洪梺绯曞墲椤ㄥ懘鍩涢幒妤佲拺缂備焦蓱鐏忣參鏌曢崼鐔稿€愮€殿喖顭烽弫宥夊礋椤忓懎濯伴梺鑽ゅТ濞诧箒銇愰崘顕嗙稏闁搞儺鍓氶崐鍨箾閸繄浠㈡繛鍛耿閺屾盯鏁愯箛鏇炲煂闂佷紮绲块崗妯虹暦婵傜鍗抽柣鎰М閺呮繈骞夐崫銉㈠亾閿濆骸鏋涢柣鎺戠仛閵囧嫰骞掗崱妞惧闂備焦瀵уú锔界濠婂牞缍栭煫鍥ㄦ媼濞差亶鏁傞柛娑卞幗椤撳ジ姊绘笟鈧褔鎮ч崱娑樼疇闊洦鎸冮幒妤€绠涢柣妤€鐗冮幏娲⒑閸涘﹦绠撻悗姘煎弮瀹曟娊鎸婃径鍡樻杸闂佺粯鍔忛弲娑欑妤ｅ啯鐓熼幖娣焺閸熷繘鏌涢悩宕囧⒌闁炽儻绠撻幃婊堟寠婢跺鈧剟姊鸿ぐ鎺戜喊闁告鍋愬▎銏ゆ倷濞村鏂€闂佺粯蓱瑜板啴顢楅姀銏㈢＝鐎广儱鎳庨埀顒€鐏濋～蹇曠磼濡顎撶紓浣割儐鐎笛冃掗幇鐗堚拺闁革富鍘搁幏锟犳煕鐎ｎ亷宸ラ柣锝囧厴椤㈡盯鎮滈崱妯绘珖闂備線娼ч悧鍡椢涘▎蹇婃灁濞寸厧鐡ㄩ埛鎴︽⒒閸喍鑵规繛鎴欏灩瀹告繃銇勯弽銉モ偓妤呮⒒?*/
    public PageResult<DeviceDto> getDevicesPaged(String username, String search, String assetNo, String serialNo,
                                                  String dept, String validity, String responsiblePerson,
                                                  String useStatus, String baselineUseStatus,
                                                  String nextDateFrom, String nextDateTo,
                                                  boolean todoOnly, int page, int size) {
        UserSettings settings = getSettings(username);
        boolean canSeePurchasePrice = canViewPurchasePrice(username);

        Optional<User> userOpt = userRepository.findByUsername(username);
        boolean isAdmin = userOpt.map(u -> "ADMIN".equals(u.getRole())).orElse(false);

        Set<String> requestedDeptScope = resolveDeptScope(dept);
        Set<String> effectiveDeptScope = requestedDeptScope;
        boolean hasDeptConstraint = !requestedDeptScope.isEmpty();
        if (!isAdmin && userOpt.isPresent()) {
            Set<String> userDeptScope = resolveDeptScope(userOpt.get().getDepartment());
            if (!userDeptScope.isEmpty()) {
                hasDeptConstraint = true;
                effectiveDeptScope = requestedDeptScope.isEmpty()
                        ? userDeptScope
                        : intersectScopes(userDeptScope, requestedDeptScope);
            }
        }

        List<String> deptScopes = hasDeptConstraint
                ? new ArrayList<>(effectiveDeptScope)
                : Collections.singletonList("__ALL__");

        int safeSize = size > 0 ? size : 20;
        int safePage = Math.max(page, 1);
        Sort sort = todoOnly
                ? Sort.by(Sort.Order.desc("daysPassed"), Sort.Order.asc("nextDate"), Sort.Order.asc("id"))
                : Sort.by(Sort.Order.asc("useStatus"), Sort.Order.asc("nextDate"), Sort.Order.asc("id"));

        String normalizedSearch = normalizeParam(search);
        String normalizedAssetNo = normalizeParam(assetNo);
        String normalizedSerialNo = normalizeParam(serialNo);
        String normalizedValidity = normalizeParam(validity);
        String normalizedResponsiblePerson = normalizeParam(responsiblePerson);
        String normalizedUseStatus = normalizeParam(useStatus);
        String normalizedBaselineUseStatus = normalizeParam(baselineUseStatus);
        LocalDate parsedNextDateFrom = parseDate(nextDateFrom);
        LocalDate parsedNextDateTo = parseDate(nextDateTo);
        boolean deptsEmpty = !hasDeptConstraint;

        Page<Device> result = deviceRepository.findWithFiltersPaged(
                normalizedSearch,
                normalizedAssetNo,
                normalizedSerialNo,
                deptScopes,
                deptsEmpty,
                normalizedValidity,
                normalizedResponsiblePerson,
                normalizedUseStatus,
                parsedNextDateFrom,
                parsedNextDateTo,
                todoOnly,
                PageRequest.of(safePage - 1, safeSize, sort)
        );

        List<DeviceDto> content = result.getContent().stream()
                .map(device -> toDto(device, settings, canSeePurchasePrice))
                .collect(Collectors.toList());

        Map<String, Long> summaryCounts = buildValiditySummary(
                normalizedSearch,
                normalizedAssetNo,
                normalizedSerialNo,
                deptScopes,
                deptsEmpty,
                normalizedValidity,
                normalizedResponsiblePerson,
                normalizedUseStatus,
                parsedNextDateFrom,
                parsedNextDateTo,
                todoOnly
        );

        Map<String, Long> useStatusSummary = buildUseStatusSummary(
                normalizedSearch,
                normalizedAssetNo,
                normalizedSerialNo,
                deptScopes,
                deptsEmpty,
                normalizedValidity,
                normalizedResponsiblePerson,
                normalizedUseStatus,
                parsedNextDateFrom,
                parsedNextDateTo,
                todoOnly
        );

        Map<String, Long> overallSummaryCounts = buildValiditySummary(
                normalizedSearch,
                normalizedAssetNo,
                normalizedSerialNo,
                deptScopes,
                deptsEmpty,
                null,
                normalizedResponsiblePerson,
                normalizedBaselineUseStatus,
                parsedNextDateFrom,
                parsedNextDateTo,
                todoOnly
        );

        Map<String, Long> overallUseStatusSummary = buildUseStatusSummary(
                normalizedSearch,
                normalizedAssetNo,
                normalizedSerialNo,
                deptScopes,
                deptsEmpty,
                null,
                normalizedResponsiblePerson,
                normalizedBaselineUseStatus,
                parsedNextDateFrom,
                parsedNextDateTo,
                todoOnly
        );

        long overallTotalElements = deviceRepository.countWithFilters(
                normalizedSearch,
                normalizedAssetNo,
                normalizedSerialNo,
                deptScopes,
                deptsEmpty,
                null,
                normalizedResponsiblePerson,
                normalizedBaselineUseStatus,
                parsedNextDateFrom,
                parsedNextDateTo,
                todoOnly
        );

        return new PageResult<>(
                content,
                result.getTotalElements(),
                result.getTotalPages(),
                safePage,
                safeSize,
                summaryCounts,
                useStatusSummary,
                overallTotalElements,
                overallSummaryCounts,
                overallUseStatusSummary
        );
    }

    public DeviceDto createDevice(String username, DeviceDto dto) {
        UserSettings settings = getSettings(username);
        Device device = fromDto(dto);
        device.setCreatedBy(username);
        recalcMetrics(device, settings);
        return toDto(deviceRepository.save(device), settings, canViewPurchasePrice(username));
    }

    public DeviceDto updateDevice(String username, Long id, DeviceDto dto) {
        UserSettings settings = getSettings(username);
        Device device = deviceRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Device not found"));
        updateFromDto(device, dto);
        recalcMetrics(device, settings);
        return toDto(deviceRepository.save(device), settings, canViewPurchasePrice(username));
    }

    public void deleteDevice(Long id) {
        deviceRepository.deleteById(id);
    }

    public DashboardStats getDashboardStats(String username) {
        UserSettings settings = getSettings(username);
        List<Device> all = deviceRepository.findAll();
        LocalDate today = LocalDate.now();
        LocalDate startOfMonth = today.withDayOfMonth(1);
        LocalDate endOfMonth = today.withDayOfMonth(today.lengthOfMonth());

        // 闂傚倸鍊搁崐鎼佸磹閹间礁纾归柟闂寸绾惧綊鏌熼梻瀵割槮缁惧墽鎳撻—鍐偓锝庝簼閹癸綁鏌ｉ鐐搭棞闁靛棙甯掗～婵嬫晲閸涱剙顥氬┑掳鍊楁慨鐑藉磻閻愮儤鍋嬮柣妯荤湽閳ь兛绶氬鎾閳╁啯鐝栭梻渚€鈧偛鑻晶鎵磼椤旂⒈鐓兼い銏＄洴閹瑩寮堕幋鏂夸壕闁汇垹鎲￠悡銉︾節闂堟稒顥㈡い搴㈩殜閺岋紕鈧綆鍋嗗ú瀛樻叏婵犲偆鐓肩€规洘甯℃俊鍫曞川椤栨瑦顢橀梻鍌欑閹碱偆鎮锕€绀夌€光偓閸曨偆鍘撮梺纭呮彧缁犳垿鐛姀銈嗙厓闁告繂瀚埀顒佸姍閺佸啴宕掑☉鎺撳缂傚倸鍊烽悞锕傛晪缂備焦顨嗙敮锟犲蓟閿濆牏鐤€闁哄倸鐏濋幗鍨節绾板纾块柡浣筋嚙閻ｇ兘鎮㈢喊杈ㄦ櫖濠殿喗锕㈢涵鎼佸船濞差亝鐓熼幖杈剧磿閻ｎ參鏌涙惔鈥宠埞閻撱倝鏌曢崼婵囶棛缂佽妫楅湁闁绘ê妯婇崕鎰版煃闁垮鐏﹂柟渚垮姂閹兘鎮ч崼鐔稿€峰┑鐘殿暯閳ь剝灏欓惌娆撴煛鐏炲墽娲村┑鈩冩倐婵＄兘鏁冮埀顒佺閹绢喗鍊垫繛鍫濈仢閺嬫稒銇勯鐘插幋鐎规洘妞藉畷鐔碱敍濮橀硸妲伴梻浣哥枃濡椼劎娆㈤敓鐘茬劦妞ゆ帊鐒﹀畷灞炬叏婵犲偆鐓肩€规洘甯掗～婵嬪础閻戝棙婢戠紓鍌氬€风粈渚€顢栭崨瀛樺亱闁规儳纾弳锕傛煙鏉堝墽鐣辩紒鐘差煼閺岋繝宕掑Ο鍝勫闂佸搫鍊甸崑鎾绘⒒娴ｇ瓔鍤欓柛鎴犳櫕缁辩偤宕卞☉妯碱槶濠电偛妫欓崹褰掓儗閸儲鐓ラ柡鍥╁仜閳ь剙缍婇幃锟犳偄閻撳海顔愰梺鍦拡閸樺ジ鎮橀敐鍥╃＜濠㈣泛鏈弳顒勬煛鐏炲墽娲撮柟顔规櫊楠炲洦鎷呴崷顓熸緬濠德板€楁慨鐑藉磻濞戔懞鍥垂椤愶紕绠氶梺缁樺灱濡嫰鎮″☉銏＄厱閻忕偛澧介惌濠冾殽閻愯尙澧︽慨濠呮閹风娀鎳犻鍌ゅ敽闂備胶顭堥鍡欑矙閹烘鐤鹃柤鍝ユ暩椤╃兘鎮楅敐搴′簻闁告挸缍婇幃妤呭礂婢跺﹣澹曢梻浣告啞濞诧箓宕滃☉銏犲偍濞寸姴顑嗛埛鎴︽偡濞嗗繐顏╅柛鏂诲€濋弻娑㈡偄闁垮浠撮梺绯曟杹閸嬫挸顪冮妶鍡楀潑闁稿鎹囬弻锝堢疀閺冨倻鐤勯梺鎸庣箘閸嬬姷绮诲☉妯锋婵☆垰婀遍悙濠囨⒒娴ｅ憡鍟為柡灞诲姂閸┾偓妞ゆ帒鍊搁弸鎴炪亜韫囨洖鈻堥柡宀€鍠庨悾锟犳焽閿曗偓閸撲即姊烘导娆戞偧闁稿繑锚閻ｇ兘宕奸弴鐐靛幐闂佺鏈粙鎺楁偟閵堝應鏀介柣妯活問閺嗘粎绱掓潏銊︾鐎规洘鍨块獮瀣晝閳ь剛澹曡ぐ鎺撶厸鐎广儱楠搁獮鏍煕閵娿儱鈧灝顫忔繝姘唶闁绘柨鍢查獮蹇撯攽閻愭潙鐏︽い顓炲€垮顕€宕煎┑鍡欑崺婵＄偑鍊栧Λ浣规叏閵堝鍋熼柡宥庡幗閳锋帒銆掑锝呬壕濠电偘鍖犻崨顔煎簥闂佺硶鍓濈粙鎴︽倿閸偁浜滈柟鍝勭Ф椤︼箑顭胯閸ㄥ爼寮诲☉銏犖ч柛鎰╁妷閸嬫挸鈹戠€ｎ亣鎽曢梺鎸庣箓濡瑩宕曢悢鍏肩厪闊洤锕ラ崳鏉库攽椤斿吋鎼愭い顏勫暣婵¤埖鎯旈垾宕囶啇婵犵數鍋涘Ο濠囧储婵傚憡鍋╃€瑰嫭澹嬮弨浠嬫倵閿濆簼绨芥い鏃€鍔栫换娑欐綇閸撗冨煂闂佸憡蓱缁捇鐛箛鎾佹椽顢旈崨顏呭闂備胶顭堥張顒€顫濋妸锔芥珷婵炴垯鍨洪悡鏇熶繆閵堝嫮鍔嶇紒鈧€ｎ兘鍋撶憴鍕闁靛牆鎲℃穱濠囨倻閽樺）銊ф喐鎼淬劍鍋傞柨婵嗘缁♀偓闂佹眹鍨藉褍鐡梻浣瑰濞插繘宕愬┑瀣畺鐟滃海鎹㈠┑瀣倞鐟滃繘寮昏椤啴濡堕崱妤冪懆闂佺锕﹂弫璇茬暦閹达箑绠婚悹鍥皺椤ρ勭節閵忥絾纭鹃柨鏇稻缁旂喖寮撮姀鈾€鎷绘繛杈剧到閹诧繝宕悙瀵哥閻犲泧鍛殼閻庤娲樼划宀勫煡婢舵劕顫呴柣妯诲絻娴滃爼姊绘担鍛婂暈缂佸鍨块弫鍐晜閸撗傜瑝婵°倧绲介崯顐ょ棯瑜旈弻娑㈩敃閿濆洨鐣甸梺鎶芥敱濡啴寮诲☉銏犵鐎广儱鎳庣粊顕€姊洪崫鍕伇闁哥姵鎹囧畷鐗堢節閸パ咁攨闂佺粯鍔栧姗€寮搁崼銉︹拻濞撴埃鍋撴繛浣冲吘娑樜旈崨顓狅紮闂佺鍕垫當缂佺姷濞€閺屸€愁吋鎼粹€崇闂佺粯鎸婚敃銏ゅ蓟閻旂⒈鏁嶉柛鈩冾殔閳ь剚鎮傝棢?
        Optional<User> userOpt = userRepository.findByUsername(username);
        boolean isAdmin = userOpt.map(u -> "ADMIN".equals(u.getRole())).orElse(false);
        String userDept = (!isAdmin && userOpt.isPresent()) ? userOpt.get().getDepartment() : null;
        Set<String> deptScope = resolveDeptScope(userDept).stream()
                .map(this::normalizeDeptName)
                .filter(s -> s != null && !s.isBlank())
                .collect(Collectors.toCollection(LinkedHashSet::new));
        if (!isAdmin && !deptScope.isEmpty()) {
            all = all.stream()
                    .filter(d -> deptScope.contains(normalizeDeptName(d.getDept())))
                    .collect(Collectors.toList());
        }

        DashboardStats stats = new DashboardStats();

        List<Device> normalDevices = all.stream()
                .filter(d -> "\u6b63\u5e38".equals(d.getUseStatus()))
                .collect(Collectors.toList());
        stats.setTotal(normalDevices.size());

        long expired = 0, warning = 0, valid = 0, dueThisMonth = 0;
        Map<String, long[]> deptMap = new LinkedHashMap<>();

        for (Device d : normalDevices) {
            LocalDate nextDate = d.getCalDate() == null
                    ? null
                    : d.getCalDate().plusMonths(normalizeCycle(d.getCycle())).minusDays(1);
            if (nextDate != null &&
                !nextDate.isBefore(startOfMonth) &&
                !nextDate.isAfter(endOfMonth)) {
                dueThisMonth++;
            }
        }

        for (Device d : normalDevices) {
            String[] metrics = calculateMetrics(d.getCalDate(), d.getCycle(),
                    settings.getWarningDays(), settings.getExpiredDays());
            String v = metrics[0];
            if ("\u5931\u6548".equals(v)) expired++;
            else if ("\u5373\u5c06\u8fc7\u671f".equals(v)) warning++;
            else valid++;

            String dept = normalizeDeptName(d.getDept());
            if (dept == null || dept.isBlank()) dept = "\u672a\u5206\u914d";
            deptMap.computeIfAbsent(dept, k -> new long[4]);
            deptMap.get(dept)[0]++;
            if ("\u5931\u6548".equals(v)) deptMap.get(dept)[3]++;
            else if ("\u5373\u5c06\u8fc7\u671f".equals(v)) deptMap.get(dept)[2]++;
            else deptMap.get(dept)[1]++;
        }

        stats.setExpired(expired);
        stats.setWarning(warning);
        stats.setValid(valid);
        stats.setDueThisMonth(dueThisMonth);

        List<Map<String, Object>> deptStats = new ArrayList<>();
        deptMap.entrySet().stream()
                .sorted((a, b) -> Long.compare(b.getValue()[0], a.getValue()[0]))
                .forEach(entry -> {
                    Map<String, Object> item = new LinkedHashMap<>();
                    item.put("dept", entry.getKey());
                    item.put("total", entry.getValue()[0]);
                    item.put("valid", entry.getValue()[1]);
                    item.put("warning", entry.getValue()[2]);
                    item.put("expired", entry.getValue()[3]);
                    deptStats.add(item);
                });
        stats.setDeptStats(deptStats);

        LocalDate sixMonthsAgo = today.minusMonths(6).withDayOfMonth(1);
        Map<String, Long> trendMap = new LinkedHashMap<>();
        for (int i = 5; i >= 0; i--) {
            LocalDate m = today.minusMonths(i).withDayOfMonth(1);
            trendMap.put(m.getYear() + "-" + String.format("%02d", m.getMonthValue()), 0L);
        }
        if (!isAdmin && !deptScope.isEmpty()) {
            for (Device d : all) {
                if (d.getCalDate() == null || d.getCalDate().isBefore(sixMonthsAgo)) continue;
                String key = d.getCalDate().getYear() + "-" + String.format("%02d", d.getCalDate().getMonthValue());
                if (trendMap.containsKey(key)) {
                    trendMap.put(key, trendMap.get(key) + 1L);
                }
            }
        } else {
            List<Object[]> rawTrend = deviceRepository.countByCalDateMonth(sixMonthsAgo);
            for (Object[] row : rawTrend) {
                int yr = ((Number) row[0]).intValue();
                int mo = ((Number) row[1]).intValue();
                long cnt = ((Number) row[2]).longValue();
                String key = yr + "-" + String.format("%02d", mo);
                if (trendMap.containsKey(key)) trendMap.put(key, cnt);
            }
        }
        List<Map<String, Object>> trend = new ArrayList<>();
        trendMap.forEach((k, v) -> {
            Map<String, Object> entry = new LinkedHashMap<>();
            entry.put("month", k);
            entry.put("count", v);
            trend.add(entry);
        });
        stats.setMonthlyTrend(trend);
        return stats;
    }

    // 闂傚倸鍊搁崐鎼佸磹閹间礁纾归柟闂寸绾惧綊鏌熼梻瀵割槮缁惧墽鎳撻—鍐偓锝庝簼閹癸綁鏌ｉ鐐搭棞闁靛棙甯掗～婵嬫晲閸涱剙顥氶梺璇叉唉椤煤閿曞倸鍨傞悹楦挎閺嗭妇绱掔€ｎ収鍤﹂柡鍐ㄧ墕閻掑灚銇勯幒鎴濐仼缁炬儳銈搁弻鏇熺節韫囨搩娲紓浣叉閸嬫挸鈹戦悩鍨毄濠殿喗鎸冲畷鎰磼濡粯鐝烽梺鍝勬川婵嘲螞椤栫偞鐓欐い鏍ф閻ジ宕ョ€ｎ喗鈷戦柛婵嗗閻忛亶鏌涢悩宕囧ⅹ闁伙絽鍢查…銊╁幢閳哄倐顒勬⒑濮瑰洤鐒洪柛銊╀憾閹嫰顢涢悙鑼舵憰闂佹寧绻傞ˇ顖滅不婵犳碍鐓曢柟閭﹀墮缁狙勭箾閸繍鐓兼慨濠冩そ瀹曨偊宕熼浣瑰缂傚倷绀侀鍡涙偋濠婂懎鍨濋悹鍥ㄧゴ濡插牓鏌曡箛鏇炐ユい鏃€鎹囧娲川婵犲倸顫呴梺杞拌閺呯娀寮崒鐐村仼鐎光偓閳ь剟顢?闂傚倸鍊搁崐鎼佸磹閹间礁纾归柟闂寸绾惧湱鈧懓瀚崳纾嬨亹閹烘垹鍊為悷婊冪箻瀵娊鏁冮崒娑氬幈濡炪値鍘介崹鍨濠靛鐓曟繛鍡楃箳缁犲鏌″畝鈧崰鏍嵁閸℃稑绾ч柛鐔峰暞閹瑰洭寮诲☉娆戠瘈闁稿本绋戞禒鎾⒑閸濆嫯顫﹂柛鏃€鍨甸锝夊箻椤旇棄鈧攱绻涢弶鎴剰濞存粓绠栭弻娑樷攽閸曨偄濮庡銈冨劜瀹€鎼佸蓟濞戞粠妲煎銈冨妼濡繈骞冮垾鏂ユ瀻闁圭偓娼欐禒顖炴⒑閸涘﹦绠撻悗姘煎弮楠炲棝宕奸悢缈犵盎闂侀潧锛忛崘褎顫曢梻浣告惈閺堫剟鎯勯娑楃箚闁绘垹鐡旈弫濠囨煟閹惧磭宀搁柟宄邦煼濮婄粯鎷呴懞銉ｂ偓鍐磼閳ь剚鎷呴懖婵囩☉閳规垹鈧綆浜ｉ幗鏇炩攽閻愭潙鐏熼柛銊ョ秺瀹曪繝骞庨懞銉у帾婵犵數鍋涢悘婵嬪礉濞嗘垹纾奸柕濞垮€楅惌娆愭叏婵犲懏顏犵紒杈ㄥ笒铻ｉ悹鍥ㄧ叀閻庢椽姊绘担瑙勫仩闁告柨鐭傞幃妯衡攽鐎ｅ墎绋忛棅顐㈡处閹峰煤椤忓秵鏅滈梺鍛婁緱閸樻椽鎮芥繝姘拻濞达絽鎲￠幆鍫熴亜閿旇棄顥嬮柍褜鍓涢悷鎶藉磼濠婂嫭顫呴梻鍌氬€搁崐鎼佸磹妞嬪海鐭嗗〒姘ｅ亾鐎规洏鍎抽埀顒婄秵娴滆泛銆掓繝姘厱鐟滃酣銆冮崨鏉戝瀭闁稿瞼鍋為悡娆愩亜閺嶃劎鐭婃い锝呭悑閵囧嫰濡烽敐鍛亾濠靛棭娼栫紓浣股戞刊瀵哥磼鐎ｎ偄顕滄慨锝嗗姍濮婃椽宕烽娑欏珱闂佺顑呴敃顏堟偘椤旂晫绡€闁告侗鍨抽弶绋库攽閻愭潙鐏︽い顓炴喘閺佸秴鈻庨幘绮规嫼濠殿喚鎳撳ú銈夋倶閳哄懏鐓欓悹鍥囧懐鐦堥梺璇″櫙缁绘繈骞冮姀銈呯闁兼祴鏅涚敮楣冩⒒婵犲骸浜滄繛灞傚€濋、鏍川閺夋垹鍔﹀銈嗗笂閼宠埖鏅堕鍫熺厓闁芥ê顦藉Σ鍏笺亜閿曗偓缂嶅﹪寮婚悢纰辨晩闁煎鍊楅悡鎾愁渻閵堝啫鐏紒瀣灴閿濈偛鈹戠€ｎ亞顢呴梺缁樺姍濞佳囩嵁濡ゅ懏鈷?闂傚倸鍊搁崐鎼佸磹閹间礁纾归柟闂寸绾惧綊鏌熼梻瀵割槮缁惧墽鎳撻—鍐偓锝庝簼閹癸綁鏌ｉ鐐搭棞闁靛棙甯掗～婵嬫晲閸涱剙顥氶梺璇叉唉椤煤閿曞倸鍨傞悹楦挎閺嗭妇绱掔€ｎ収鍤﹂柡鍐ㄧ墕閻掑灚銇勯幒鎴濐仼缁炬儳銈搁弻鏇熺節韫囨搩娲紓浣叉閸嬫挸鈹戦悩鍨毄濠殿喗鎸冲畷鎰磼濡粯鐝烽梺鍝勬川婵嘲螞椤栫偞鐓欐い鏍ф閻ジ宕ョ€ｎ喗鈷戦柛婵嗗閻忛亶鏌涢悩宕囧ⅹ闁伙絽鍢查…銊╁幢閳哄倐顒勬⒑濮瑰洤鐒洪柛銊╀憾閹嫰顢涢悙鑼舵憰闂佹寧绻傞ˇ顖滅不婵犳碍鐓曢柟閭﹀墮缁狙勭箾閸繍鐓兼慨濠冩そ瀹曨偊宕熼浣瑰缂傚倷绀侀鍡涙偋濠婂懎鍨濋悹鍥ㄧゴ濡插牓鏌曡箛鏇炐ユい鏃€鎹囧娲川婵犲倸顫呴梺杞拌閺呯娀寮崒鐐村仼鐎光偓閳ь剟顢欓弴銏＄厽閹兼番鍨婚埊鏇熴亜椤撶偞鍠橀柟顖氱焸楠炴帡寮崒婊愮床闂備胶绮敋缁剧虎鍘介弲鍫曨敂閸涱偂绨诲銈嗗姂閸ㄨ崵绮绘导瀛樺亗闁靛牆妫庢禍婊堢叓閸ャ劍灏い蹇ｅ亝閵囧嫰鏁傞崫鍕潎濠殿喖锕ュ钘夌暦閻戠瓔鏁囬柣妯垮皺椤愬ジ姊哄Ч鍥х労闁搞劏浜弫顔嘉旈埀顒勨€﹂崶顏嗙杸婵炴垶锚缁愭盯鏌ｆ惔銏⑩姇閼裤倝鏌熼悿顖涱仩缂佽鲸鎸婚幏鍛村礈閹绘帒澹夋俊鐐€栭崹鍫曟偡閳轰胶鏆﹂柡鍥ュ灩缁犳盯鏌ｅΔ鈧悧蹇涘储閻㈠憡鈷戦柤濮愬€曢弸鏂款熆瑜庨〃濠傜暦閺夎鐔轰焊閺嵮傚濠电偛鐗嗛悘婵嬪几閿斿浜滈柡鍥ф濞村倿寮崶顒佺厱闊洦娲栫敮鍓佺磼閸撲礁浠滈柍瑙勫灴閹晠骞撻幒婵呯礉婵犵鈧櫕鈻曢柛銊ゅ嵆閸╃偤骞嬮敂钘変汗濡炪倖妫侀崑鎰閸パ€鏀介柣鎰▕濡插綊鏌ｉ埡濠傜仸鐎殿噮鍋婂畷姗€顢欓懞銉︾彸闂備胶纭堕崜婵嬫偡瑜戦妵鎰偅閸愨斁鎷洪梺鍛婄箓鐎氼參宕掗妸鈺傜厱闁靛闄勯妵婵嬫煕閳哄倻娲存鐐村浮楠炲﹪濡搁妷褏楔闂佽桨鐒﹂崝娆忕暦閸洖绀堝ù锝囶焾姝囬梻鍌氬€风粈渚€骞栭鈶芥稑鈹戦崶鈺婃锤闂佸壊鍋呭ú鏍嫅閻斿摜绠鹃柟瀵稿剱閻掓悂鏌ｉ弬鍨倯闁搞倖甯￠弻鏇㈠醇濠靛洤绐涢梺鍛娚戠划鎾诲蓟閿濆棙鍎熼柕鍫濆缂嶅牆鈹戦悙鎻掔骇闁挎洏鍨归悾鐤亹閹烘垿鏁滃┑掳鍊曢崯顐ょ矈閿曗偓閳规垿鍩ラ崱妤冧淮闂佺顑嗛崝妤佺珶閺囥垹绀傞梻鍌氼嚟缁犳艾顪冮妶鍡欏缂侇喖鐬奸弫顕€宕奸弴鐔蜂缓濡炪倖鐗楁笟妤€鈻撳鍕弿濠电姴瀚敮娑㈡煙瀹勭増鍣虹紒妤冨枛椤㈡稑顭ㄩ崘銊愵亞绱撻崒姘偓鐑芥嚄閸撲礁鍨濇い鏍仜缁€澶嬬箾閸℃ê绗氭い銉ｅ€栨穱濠囨倷椤忓嫧鍋撻弽顓熷亱婵°倕鍟伴惌娆撴煙閻愵剛婀介柍褜鍓欓幊姗€鐛幘璇茬闁靛闄勯ˉ鍫ユ煛娴ｇ懓濮嶇€规洏鍔戦、姗€鎮㈤崜鎻掓暭闂傚倸鍊烽悞锔界箾婵犲洤缁╅梺顒€绉撮崹鍌炴煕瑜庨〃鍛存嫅閻斿摜绠鹃柟瀛樼懃閻忊晝绱掗悩宕団姇闁靛洤瀚伴獮妯兼崉鏉炵増鍩涚紓鍌欐閼冲爼宕楀鈧濠氭晲婢跺娼婇梺瀹犳〃閼宠埖绂掑鍫熲拺闁告稑锕ラ埛鎰版煕閵娿儳浠㈡い鏇悼閹风姴霉鐎ｎ偒娼旀繝娈垮枟閿曨偆寰婇懞銉ь洸濡わ絽鍟悡銉︾節闂堟稒顥㈡い搴㈩殔闇夋繝濠傚缁犳﹢鏌嶈閸撴繈锝炴径濞掓椽寮介鐔峰壒闂佺鐬奸崑娑㈡嫅閻斿吋鐓ユ繛鎴灻褎绻涘畝濠侀偗闁哄矉缍侀弫鎰板川椤栨稑浠撮柣鐔哥矊缁绘﹢宕洪埀顒併亜閹烘垵鏋ゆ繛鍏煎姈缁绘盯宕ｆ径娑溾偓鍧楁煏閸℃鏆ｇ€规洖宕灃濠电姴鍊归鍌炴⒒娴ｅ憡鍟炴繛璇х畵瀹曟粌鈽夊顒€袣闂侀€炲苯澧紒缁樼⊕濞煎繘宕滆閸╁本绻濋姀銏″殌闁挎洏鍊涢悘瀣攽閻樿宸ラ柣妤€锕崺娑㈠箳濡や胶鍘遍柣蹇曞仦瀹曟ɑ绔熷鈧弻宥堫檨闁告挾鍠栬棢闁规崘娉涢崹婵嬫煕椤愩倕鏋旈柣鐔风秺閺屽秷顧侀柛鎾寸懇閹箖鎮滅粵瀣櫖闂佺粯鍔栭悡锟犲极濠婂啠鏀介幒鎶藉磹閹版澘纾婚柟鍓х帛閻撴洟鎮橀悙棰濆殭濠碉紕鏅槐鎺旂磼濡偐鐣虹紓浣虹帛缁诲牆鐣烽幒鎴叆闁告劗鍋撳В鍥╃磽閸屾瑨鍏岄柛瀣崌瀹曟洟骞庣憴锝傚亾閿曞倹鍊婚柦妯侯槼閹芥洟姊虹紒妯烩拻闁告鍛焼闁割偁鍨洪崰鎰扮叓閸ャ劍绀冮柡鍡樼矋缁绘盯骞嬪▎蹇曚痪闂佺粯鎸鹃崰鏍蓟閻旂厧绠氱憸宥夊汲闁秵鐓涢柛鈽嗗幘缁夘噣鏌″畝瀣？濞寸媴绠撳畷婊嗩檨闁诲繗浜槐鎾存媴閸濆嫅锝夋煟閳哄﹤鐏﹂柣娑卞枛閳诲酣骞樺畷鍥舵О闂備礁鐤囬鏍礈閵娾晜鈷旈柛鏇ㄥ幗瀹曞弶绻涢幋鐐茬劰闁稿鎸搁埥澶娾枎濡厧濮洪梻浣规た閸樼晫鏁悙鍨潟闁圭儤顨嗛崑鎰偓瑙勬礀濞层倝鍩呴悷閭︽富闁靛牆楠告禍婊呯磼缂佹ê濮夐柛娆忔噹椤啴濡堕崨顖滎唶闁诲孩鍑归崳锝堟闂侀潧艌閺呮粓鍩涢幋锔界厱闁挎棁顕ч獮姗€鎮介娑氭创闁诡喕绮欓、娑樷槈濡偐鎳栨繝鐢靛仧閸樠呮崲濡櫣鏆﹂柕濞р偓閸嬫挸鈽夊▍杈ㄥ哺楠炲繘鎼归崷顓狅紳婵炶揪绲芥竟濠囧磿閹邦厹浜滈柟瀵稿仧閹冲洨鈧娲樺ú鐔肩嵁閸ヮ剚鍋嬮柛顐犲灩楠炲秹姊绘担钘夊惞闁哥姵鎸婚弲璺何旈崨顓犵崶濠碘槅鍨伴惃鐑藉磻閹炬枼鏋旈柛顭戝枟閻忔洖顪冮妶鍡樿偁闁搞儴鍩栭弲锝夋⒑缁嬭法绠抽柛妯犲懏顐介柣鎰ゴ閺€浠嬫煟濡绲绘い蹇撶摠娣囧﹤顔忛鑲╀哗闂佸疇顫夐崹鍧楀箖閳哄拋鏁婇柤娴嬫櫃缁辨ɑ绻濋悽闈涗粶妞わ缚鍗抽幆鍕敍閻愬弶鐎梺鍛婂姦閸犳寮查弻銉︾厱闁斥晛鍟伴幊鍛喐娴煎鐣烘慨濠冩そ瀹曨偊宕熼鈧崑宥夋⒑閹肩偛濡芥俊鐐扮矙瀹曞搫鈽夐姀鐘殿唺闂佸湱鍋ㄩ崝宀€绱炴繝鍥ф瀬闁圭増婢橀悙濠囨煕閹捐尙顦﹀┑顔笺偢濮婄粯鎷呴崨濠冨創濠碘槅鍋呯换鍐矉瀹ュ閱囬柡鍥╁仩閹芥洖鈹戦悙鏉戠仸妞ゎ厼鍊块幃銏ゅ礂閻撳孩顓奸梻渚€娼ч悧鍡椕洪妸鈺佸偍婵犲﹤鐗婇悡鐔煎箹濞ｎ剙鈧倕顭囬幇顓犵闁告瑥顧€閼拌法鈧娲栫紞濠傜暦缁嬭鏃堝礃閵娧佸亰濠电姷顣藉Σ鍛村垂閻㈢纾婚柟閭﹀枛椤ユ岸鏌涜箛娑欙紵缂佽妫欓妵鍕冀閵娧呯厐闁汇埄鍨伴悥濂稿箖娴犲鏁嶆繛鎴ｉ哺閻や礁鈹戦纭峰姛缂侇噮鍨堕獮蹇涘川椤斿墽鎳濆銈嗙墬缁本鎱ㄩ懖鈺冪＝闁稿本鐟ㄩ崗宀€绱掗鍛仸鐎规洘绻傞埢搴ㄥ箳閹垮啯锛堟繝纰夌磿閸嬫垿宕愰弽顓熷亱婵°倕鍟伴惌娆撴煙閻愵剛婀介柍褜鍓欓幊姗€鐛幘璇茬闁靛闄勯ˉ鍫ユ煛娴ｇ懓濮嶇€规洏鍔戦、姗€鎮㈤崜鎻掓暭闂傚倸鍊烽悞锔界箾婵犲洤缁╅梺顒€绉撮崹鍌炴煕瑜庨〃鍛存嫅閻斿摜绠鹃柟瀛樼懃閻忊晝绱掗悩宕団姇闁靛洤瀚伴獮妯兼崉鏉炵増鍩涚紓鍌欐閼冲爼宕楀鈧濠氭晲婢跺娼婇梺瀹犳〃閼宠埖绂掑鍫熲拺闁告稑锕ラ埛鎰版煕閵娿儳浠㈡い鏇悼閹风姴霉鐎ｎ偒娼旀繝娈垮枟閿曨偆寰婇懞銉ь洸濡わ絽鍟悡銉︾節闂堟稒顥㈡い搴㈩殔闇夋繝濠傚缁犳﹢鏌嶈閸撴繈锝炴径濞掓椽寮介鐔峰壒闂佺鐬奸崑娑㈡嫅閻斿吋鐓ユ繛鎴灻褎绻涘畝濠侀偗闁哄矉缍侀弫鎰板川椤栨稑浠撮柣鐔哥矊缁绘﹢宕洪埀顒併亜閹烘垵鏋ゆ繛鍏煎姈缁绘盯宕ｆ径娑溾偓鍧楁煏閸℃鏆ｇ€规洖宕灃濠电姴鍊归鍌炴⒒娴ｅ憡鍟炴繛璇х畵瀹曟粌鈽夊顒€袣闂侀€炲苯澧紒缁樼⊕濞煎繘宕滆閸╁本绻濋姀銏″殌闁挎洏鍊涢悘瀣攽閻樿宸ラ柣妤€锕崺娑㈠箳濡や胶鍘遍柣蹇曞仦瀹曟ɑ绔熷鈧弻宥堫檨闁告挾鍠栬棢闁规崘娉涢崹婵嬫煕椤愩倕鏋旈柣鐔风秺閺屽秷顧侀柛鎾寸懇閹箖鎮滅粵瀣櫖闂佺粯鍔栭悡锟犲极濠婂啠鏀介幒鎶藉磹閹版澘纾婚柟鍓х帛閻撴洟鎮橀悙棰濆殭濠碉紕鏅槐鎺旂磼濡偐鐣虹紓浣虹帛缁诲牆鐣烽幒鎴叆闁告劗鍋撳В鍥╃磽閸屾瑨鍏岄柛瀣崌瀹曟洟骞庣憴锝傚亾閿曞倹鍊婚柦妯侯槼閹芥洟姊虹紒妯烩拻闁告鍛焼闁割偁鍨洪崰鎰扮叓閸ャ劍绀冮柡鍡樼矋缁绘盯骞嬪▎蹇曚痪闂佺粯鎸鹃崰鏍蓟閻旂厧绠氱憸宥夊汲闁秵鐓涢柛鈽嗗幘缁夘噣鏌″畝瀣？濞寸媴绠撳畷婊嗩檨闁诲繗浜槐鎾存媴閸濆嫅锝夋煟閳哄﹤鐏﹂柣娑卞枛閳诲酣骞樺畷鍥舵О闂備礁鐤囬鏍礈閵娾晜鈷旈柛鏇ㄥ幗瀹曞弶绻涢幋鐐茬劰闁稿鎸搁埥澶娾枎濡厧濮洪梻浣规た閸樼晫鏁悙鍨潟闁圭儤顨嗛崑鎰偓瑙勬礀濞层倝鍩呴悷閭︽富闁靛牆楠告禍婊呯磼缂佹ê濮夐柛娆忔噹椤啴濡堕崨顖滎唶闁诲孩鍑归崳锝堟闂侀潧艌閺呮粓鍩涢幋锔界厱闁挎棁顕ч獮姗€鎮介娑氭创闁诡喕绮欓、娑樷槈濡偐鎳栨繝鐢靛仧閸樠呮崲濡櫣鏆﹂柕濞р偓閸嬫挸鈽夊▍杈ㄥ哺楠炲繘鎼归崷顓狅紳婵炶揪绲芥竟濠囧磿閹邦厹浜滈柟瀵稿仧閹冲洨鈧娲樺ú鐔肩嵁閸ヮ剚鍋嬮柛顐犲灩楠炲秹姊绘担钘夊惞闁哥姵鎸婚弲璺何旈崨顓犵崶濠碘槅鍨伴惃鐑藉磻閹炬枼鏋旈柛顭戝枟閻忔洖顪冮妶鍡樿偁闁搞儴鍩栭弲锝夋⒑缁嬭法绠抽柛妯犲懏顐介柣鎰ゴ閺€浠嬫煟濡绲绘い蹇撶摠娣囧﹤顔忛鑲╀哗闂佸疇顫夐崹鍧楀箖閳哄拋鏁婇柤娴嬫櫃缁辨ɑ绻濋悽闈涗粶妞わ缚鍗抽幆鍕敍閻愬弶鐎梺鍛婂姦閸犳寮查弻銉︾厱闁斥晛鍟伴幊鍛喐娴煎鐣烘慨濠冩そ瀹曨偊宕熼鈧崑宥夋⒑閹肩偛濡芥俊鐐扮矙瀹曞搫鈽夐姀鐘殿唺闂佸湱鍋ㄩ崝宀€绱炴繝鍥ф瀬闁圭増婢橀悙濠囨煕閹捐尙顦﹀┑顔笺偢濮婄粯鎷呴崨濠冨創濠碘槅鍋呯换鍐矉瀹ュ閱囬柡鍥╁仩閹芥洖鈹戦悙鏉戠仸妞ゎ厼鍊块幃銏ゅ礂閻撳孩顓奸梻渚€娼ч悧鍡椕洪妸鈺佸偍婵犲﹤鐗婇悡鐔煎箹濞ｎ剙鈧倕顭囬幇顓犵闁告瑥顧€閼拌法鈧娲栫紞濠傜暦缁嬭鏃堝礃閵娧佸亰濠电姷顣藉Σ鍛村垂閻㈢纾婚柟閭﹀枛椤ユ岸鏌涜箛娑欙紵缂佽妫欓妵鍕冀閵娧呯厐闁汇埄鍨伴悥濂稿箖娴犲鏁嶆繛鎴ｉ哺閻や礁鈹戦纭峰姛缂侇噮鍨堕獮蹇涘川椤斿墽鎳濆銈嗙墬缁本鎱ㄩ懖鈺冪＝闁稿本鐟ㄩ崗宀€绱掗鍛仸鐎规洘绻傞埢搴ㄥ箳閹垮啯锛堟繝纰夌磿閸嬫垿宕愰弽顓熷亱婵°倕鍟伴惌娆撴煙閻愵剛婀介柍褜鍓欓幊姗€鐛幘璇茬闁靛闄勯ˉ鍫ユ煛娴ｇ懓濮嶇€规洏鍔戦、姗€鎮㈤崜鎻掓暭闂傚倸鍊烽悞锔界箾婵犲洤缁╅梺顒€绉撮崹鍌炴煕瑜庨〃鍛存嫅閻斿摜绠鹃柟瀛樼懃閻忊晝绱掗悩宕団姇闁靛洤瀚伴獮妯兼崉鏉炵増鍩涚紓鍌欐閼冲爼宕楀鈧濠氭晲婢跺娼婇梺瀹犳〃閼宠埖绂掑鍫熲拺闁告稑锕ラ埛鎰版煕閵娿儳浠㈡い鏇悼閹风姴霉鐎ｎ偒娼旀繝娈垮枟閿曨偆寰婇懞銉ь洸濡わ絽鍟悡銉︾節闂堟稒顥㈡い搴㈩殔闇夋繝濠傚缁犳﹢鏌嶈閸撴繈锝炴径濞掓椽寮介鐔峰壒闂佺鐬奸崑娑㈡嫅閻斿吋鐓ユ繛鎴灻褎绻涘畝濠侀偗闁哄矉缍侀弫鎰板川椤栨稑浠撮柣鐔哥矊缁绘﹢宕洪埀顒併亜閹烘垵鏋ゆ繛鍏煎姈缁绘盯宕ｆ径娑溾偓鍧楁煏閸℃鏆ｇ€规洖宕灃濠电姴鍊归鍌炴⒒娴ｅ憡鍟炴繛璇х畵瀹曟粌鈽夊顒€袣闂侀€炲苯澧紒缁樼⊕濞煎繘宕滆閸╁本绻濋姀銏″殌闁挎洏鍊涢悘瀣攽閻樿宸ラ柣妤€锕崺娑㈠箳濡や胶鍘遍柣蹇曞仦瀹曟ɑ绔熷鈧弻宥堫檨闁告挾鍠栬棢闁规崘娉涢崹婵嬫煕椤愩倕鏋旈柣鐔风秺閺屽秷顧侀柛鎾寸懇閹箖鎮滅粵瀣櫖闂佺粯鍔栭悡锟犲极濠婂啠鏀介幒鎶藉磹閹版澘纾婚柟鍓х帛閻撴洟鎮橀悙棰濆殭濠碉紕鏅槐鎺旂磼濡偐鐣虹紓浣虹帛缁诲牆鐣烽幒鎴叆闁告劗鍋撳В鍥╃磽閸屾瑨鍏岄柛瀣崌瀹曟洟骞庣憴锝傚亾閿曞倹鍊婚柦妯侯槼閹芥洟姊虹紒妯烩拻闁告鍛焼闁割偁鍨洪崰鎰扮叓閸ャ劍绀冮柡鍡樼矋缁绘盯骞嬪▎蹇曚痪闂佺粯鎸鹃崰鏍蓟閻旂厧绠氱憸宥夊汲闁秵鐓涢柛鈽嗗幘缁夘噣鏌″畝瀣？濞寸媴绠撳畷婊嗩檨闁诲繗浜槐鎾存媴閸濆嫅锝夋煟閳哄﹤鐏﹂柣娑卞枛閳诲酣骞樺畷鍥舵О闂備礁鐤囬鏍礈閵娾晜鈷旈柛鏇ㄥ幗瀹曞弶绻涢幋鐐茬劰闁稿鎸搁埥澶娾枎濡厧濮洪梻浣规た閸樼晫鏁悙鍨潟闁圭儤顨嗛崑鎰偓瑙勬礀濞层倝鍩呴悷閭︽富闁靛牆楠告禍婊呯磼缂佹ê濮夐柛娆忔噹椤啴濡堕崨顖滎唶闁诲孩鍑归崳锝堟闂侀潧艌閺呮粓鍩涢幋锔界厱闁挎棁顕ч獮姗€鎮介娑氭创闁诡喕绮欓、娑樷槈濡偐鎳栨繝鐢靛仧閸樠呮崲濡櫣鏆﹂柕濞р偓閸嬫挸鈽夊▍杈ㄥ哺楠炲繘鎼归崷顓狅紳婵炶揪绲芥竟濠囧磿閹邦厹浜滈柟瀵稿仧閹冲洨鈧娲樺ú鐔肩嵁閸ヮ剚鍋嬮柛顐犲灩楠炲秹姊绘担钘夊惞闁哥姵鎸婚弲璺何旈崨顓犵崶濠碘槅鍨伴惃鐑藉磻閹炬枼鏋旈柛顭戝枟閻忔洖顪冮妶鍡樿偁闁搞儴鍩栭弲锝夋⒑缁嬭法绠抽柛妯犲懏顐介柣鎰ゴ閺€浠嬫煟濡绲绘い蹇撶摠娣囧﹤顔忛鑲╀哗闂佸疇顫夐崹鍧楀箖閳哄拋鏁婇柤娴嬫櫃缁辨ɑ绻濋悽闈涗粶妞わ缚鍗抽幆鍕敍閻愬弶鐎梺鍛婂姦閸犳寮查弻銉︾厱闁斥晛鍟伴幊鍛喐娴煎鐣烘慨濠冩そ瀹曨偊宕熼鈧崑宥夋⒑閹肩偛濡芥俊鐐扮矙瀹曞搫鈽夐姀鐘殿唺闂佸湱鍋ㄩ崝宀€绱炴繝鍥ф瀬闁圭増婢橀悙濠囨煕閹捐尙顦﹀┑顔笺偢濮婄粯鎷呴崨濠冨創濠碘槅鍋呯换鍐矉瀹ュ閱囬柡鍥╁仩閹芥洖鈹戦悙鏉戠仸妞ゎ厼鍊块幃銏ゅ礂閻撳孩顓奸梻渚€娼ч悧鍡椕洪妸鈺佸偍婵犲﹤鐗婇悡鐔煎箹濞ｎ剙鈧倕顭囬幇顓犵闁告瑥顧€閼拌法鈧娲栫紞濠傜暦缁嬭鏃堝礃閵娧佸亰濠电姷顣藉Σ鍛村垂閻㈢纾婚柟閭﹀枛椤ユ岸鏌涜箛娑欙紵缂佽妫欓妵鍕冀閵娧呯厐闁汇埄鍨伴悥濂稿箖娴犲鏁嶆繛鎴ｉ哺閻や礁鈹戦纭峰姛缂侇噮鍨堕獮蹇涘川椤斿墽鎳濆銈嗙墬缁本鎱ㄩ懖鈺冪＝闁稿本鐟ㄩ崗宀€绱掗鍛仸鐎规洘绻傞埢搴ㄥ箳閹垮啯锛堟繝纰夌磿閸嬫垿宕愰弽顓熷亱婵°倕鍟伴惌娆撴煙閻愵剛婀介柍?
    public byte[] exportExcel(String username, String search, String assetNo, String serialNo,
                              String dept, String validity, String useStatus) throws IOException {
        boolean canSeePurchasePrice = canViewPurchasePrice(username);
        List<DeviceDto> dtos = getDevices(username, search, assetNo, serialNo, dept, validity, null, useStatus);
        try (Workbook wb = new XSSFWorkbook()) {
            Sheet sheet = wb.createSheet("devices");
            String[] headers = {
                    "设备名称","计量编号","资产编号","出厂编号","ABC分类","使用部门","存放地点",
                    "生产厂家","规格型号","责任人","购置日期","购置价格","使用年限",
                    "校准周期(月)","校准日期","下次校准日期","有效状态","校准结果",
                    "分度值","测量范围","允许误差","使用状态","备注"
            };

            CellStyle hStyle = wb.createCellStyle();
            Font hFont = wb.createFont();
            hFont.setBold(true);
            hStyle.setFont(hFont);
            hStyle.setFillForegroundColor(IndexedColors.LIGHT_CORNFLOWER_BLUE.getIndex());
            hStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            CellStyle dateStyle = wb.createCellStyle();
            dateStyle.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("yyyy-MM-dd"));

            Row headerRow = sheet.createRow(0);
            for (int i = 0; i < headers.length; i++) {
                Cell c = headerRow.createCell(i);
                c.setCellValue(headers[i]);
                c.setCellStyle(hStyle);
                sheet.setColumnWidth(i, 4200);
            }

            int rowNum = 1;
            for (DeviceDto d : dtos) {
                Row row = sheet.createRow(rowNum++);
                row.createCell(0).setCellValue(s(d.getName()));
                row.createCell(1).setCellValue(s(d.getMetricNo()));
                row.createCell(2).setCellValue(s(d.getAssetNo()));
                row.createCell(3).setCellValue(s(d.getSerialNo()));
                row.createCell(4).setCellValue(s(d.getAbcClass()));
                row.createCell(5).setCellValue(s(d.getDept()));
                row.createCell(6).setCellValue(s(d.getLocation()));
                row.createCell(7).setCellValue(s(d.getManufacturer()));
                row.createCell(8).setCellValue(s(d.getModel()));
                row.createCell(9).setCellValue(s(d.getResponsiblePerson()));

                if (d.getPurchaseDate() != null && !d.getPurchaseDate().isBlank()) {
                    Cell dc = row.createCell(10);
                    dc.setCellValue(LocalDate.parse(d.getPurchaseDate()));
                    dc.setCellStyle(dateStyle);
                } else row.createCell(10).setCellValue("");

                if (canSeePurchasePrice && d.getPurchasePrice() != null) row.createCell(11).setCellValue(d.getPurchasePrice()); else row.createCell(11).setCellValue("");
                if (d.getServiceLife() != null) row.createCell(12).setCellValue(d.getServiceLife()); else row.createCell(12).setCellValue("");
                if (d.getCycle() != null) row.createCell(13).setCellValue(d.getCycle()); else row.createCell(13).setCellValue("");

                if (d.getCalDate() != null && !d.getCalDate().isBlank()) {
                    Cell dc = row.createCell(14);
                    dc.setCellValue(LocalDate.parse(d.getCalDate()));
                    dc.setCellStyle(dateStyle);
                } else row.createCell(14).setCellValue("");

                if (d.getNextDate() != null && !d.getNextDate().isBlank()) {
                    Cell dc = row.createCell(15);
                    dc.setCellValue(LocalDate.parse(d.getNextDate()));
                    dc.setCellStyle(dateStyle);
                } else row.createCell(15).setCellValue("");

                row.createCell(16).setCellValue(s(d.getValidity()));
                row.createCell(17).setCellValue(s(d.getCalibrationResult()));
                row.createCell(18).setCellValue(s(d.getGraduationValue()));
                row.createCell(19).setCellValue(s(d.getTestRange()));
                row.createCell(20).setCellValue(s(d.getAllowableError()));
                row.createCell(21).setCellValue(s(d.getUseStatus()));
                row.createCell(22).setCellValue(s(d.getRemark()));
            }

            ByteArrayOutputStream out = new ByteArrayOutputStream();
            wb.write(out);
            return out.toByteArray();
        }
    }

    public byte[] exportCalibration(String username, String search, String dept,
                                    String validity, String responsiblePerson) throws IOException {
        List<DeviceDto> dtos = getDevices(username, search, null, null, dept, validity, responsiblePerson, null);
        try (Workbook wb = new XSSFWorkbook()) {
            Sheet sheet = wb.createSheet("calibration");
            String[] headers = {
                    "设备名称","计量编号","使用部门","责任人",
                    "校准日期","下次校准日期","校准周期(月)","有效状态","校准结果","使用状态","备注"
            };

            CellStyle hStyle = wb.createCellStyle();
            Font hFont = wb.createFont();
            hFont.setBold(true);
            hStyle.setFont(hFont);
            hStyle.setFillForegroundColor(IndexedColors.LIGHT_GREEN.getIndex());
            hStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            Row headerRow = sheet.createRow(0);
            for (int i = 0; i < headers.length; i++) {
                Cell c = headerRow.createCell(i);
                c.setCellValue(headers[i]);
                c.setCellStyle(hStyle);
                sheet.setColumnWidth(i, 4200);
            }

            int rowNum = 1;
            for (DeviceDto d : dtos) {
                Row row = sheet.createRow(rowNum++);
                row.createCell(0).setCellValue(s(d.getName()));
                row.createCell(1).setCellValue(s(d.getMetricNo()));
                row.createCell(2).setCellValue(s(d.getDept()));
                row.createCell(3).setCellValue(s(d.getResponsiblePerson()));
                row.createCell(4).setCellValue(s(d.getCalDate()));
                row.createCell(5).setCellValue(s(d.getNextDate()));
                if (d.getCycle() != null) row.createCell(6).setCellValue(d.getCycle()); else row.createCell(6).setCellValue("");
                row.createCell(7).setCellValue(s(d.getValidity()));
                row.createCell(8).setCellValue(s(d.getCalibrationResult()));
                row.createCell(9).setCellValue(s(d.getUseStatus()));
                row.createCell(10).setCellValue(s(d.getRemark()));
            }

            ByteArrayOutputStream out = new ByteArrayOutputStream();
            wb.write(out);
            return out.toByteArray();
        }
    }

    public byte[] getTemplate() throws IOException {
        try (Workbook wb = new XSSFWorkbook()) {
            Sheet sheet = wb.createSheet("template");
            String[] headers = {
                    "设备名称*","计量编号*","资产编号","出厂编号","ABC分类","使用部门","存放地点",
                    "生产厂家","规格型号","责任人","购置日期","购置价格","使用年限(自动)",
                    "校准周期（月，6/12）","校准日期","下次校准日期(自动)","有效状态(自动)","校准结果",
                    "分度值","测量范围","允许误差","使用状态","备注"
            };

            CellStyle reqStyle = wb.createCellStyle();
            Font reqFont = wb.createFont();
            reqFont.setBold(true);
            reqStyle.setFont(reqFont);
            reqStyle.setFillForegroundColor(IndexedColors.YELLOW.getIndex());
            reqStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            CellStyle optStyle = wb.createCellStyle();
            Font optFont = wb.createFont();
            optFont.setBold(true);
            optStyle.setFont(optFont);
            optStyle.setFillForegroundColor(IndexedColors.LIGHT_CORNFLOWER_BLUE.getIndex());
            optStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            CellStyle autoStyle = wb.createCellStyle();
            Font autoFont = wb.createFont();
            autoFont.setBold(true);
            autoStyle.setFont(autoFont);
            autoStyle.setFillForegroundColor(IndexedColors.GREY_25_PERCENT.getIndex());
            autoStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            CellStyle dateStyle = wb.createCellStyle();
            dateStyle.setDataFormat(wb.getCreationHelper().createDataFormat().getFormat("yyyy-MM-dd"));

            Set<Integer> autoCols = Set.of(12, 15, 16);
            Set<Integer> reqCols = Set.of(0, 1);

            Row headerRow = sheet.createRow(0);
            for (int i = 0; i < headers.length; i++) {
                Cell c = headerRow.createCell(i);
                c.setCellValue(headers[i]);
                c.setCellStyle(autoCols.contains(i) ? autoStyle : reqCols.contains(i) ? reqStyle : optStyle);
                sheet.setColumnWidth(i, i == 12 || i == 15 || i == 16 ? 5500 : 4200);
            }

            Row ex = sheet.createRow(1);
            ex.createCell(0).setCellValue("示例设备");
            ex.createCell(1).setCellValue("M2024001");
            ex.createCell(2).setCellValue("ZC001");
            ex.createCell(3).setCellValue("SN12345");
            ex.createCell(4).setCellValue("A");
            ex.createCell(5).setCellValue("生产一部");
            ex.createCell(6).setCellValue("一号车间");
            ex.createCell(7).setCellValue("Mitutoyo");
            ex.createCell(8).setCellValue("CD-20AX");
            ex.createCell(9).setCellValue("张三");
            Cell pdCell = ex.createCell(10);
            pdCell.setCellValue(LocalDate.of(2022, 3, 1));
            pdCell.setCellStyle(dateStyle);
            ex.createCell(11).setCellValue(1200.00);
            ex.createCell(12).setCellValue("(auto)");
            ex.createCell(13).setCellValue(12);
            Cell cdCell = ex.createCell(14);
            cdCell.setCellValue(LocalDate.of(2025, 1, 15));
            cdCell.setCellStyle(dateStyle);
            ex.createCell(15).setCellValue("(auto)");
            ex.createCell(16).setCellValue("(auto)");
            ex.createCell(17).setCellValue("合格");
            ex.createCell(18).setCellValue("0.01mm");
            ex.createCell(19).setCellValue("0-200mm");
            ex.createCell(20).setCellValue("±0.02mm");
            ex.createCell(21).setCellValue("在用");
            ex.createCell(22).setCellValue("示例备注");

            ByteArrayOutputStream out = new ByteArrayOutputStream();
            wb.write(out);
            return out.toByteArray();
        }
    }

    public int importExcel(String username, MultipartFile file) throws IOException {
        UserSettings settings = getSettings(username);
        int count = 0;
        try (Workbook wb = WorkbookFactory.create(file.getInputStream())) {
            Sheet sheet = wb.getSheetAt(0);
            Row headerRow = sheet.getRow(0);
            Map<String, Integer> colMap = new HashMap<>();
            for (int i = 0; i < headerRow.getLastCellNum(); i++) {
                Cell c = headerRow.getCell(i);
                if (c != null) {
                    String key = normalizeImportHeader(c.getStringCellValue());
                    String canonicalKey = toImportFieldKey(key);
                    if (canonicalKey != null) {
                        colMap.put(canonicalKey, i);
                    }
                }
            }

            for (int r = 1; r <= sheet.getLastRowNum(); r++) {
                Row row = sheet.getRow(r);
                if (row == null) continue;
                String name = getCellStr(row, colMap.get("name"));
                String metricNo = getCellStr(row, colMap.get("metricNo"));
                if (name == null || name.isBlank() || metricNo == null || metricNo.isBlank()) continue;

                Device d = new Device();
                d.setName(name);
                d.setMetricNo(metricNo);
                d.setAssetNo(getCellStr(row, colMap.get("assetNo")));
                d.setSerialNo(getCellStr(row, colMap.get("serialNo")));
                d.setAbcClass(getCellStr(row, colMap.get("abcClass")));
                d.setDept(getCellStr(row, colMap.get("dept")));
                d.setLocation(getCellStr(row, colMap.get("location")));
                d.setManufacturer(getCellStr(row, colMap.get("manufacturer")));
                d.setModel(getCellStr(row, colMap.get("model")));
                d.setResponsiblePerson(getCellStr(row, colMap.get("responsiblePerson")));
                d.setGraduationValue(getCellStr(row, colMap.get("graduationValue")));
                d.setTestRange(getCellStr(row, colMap.get("testRange")));
                d.setAllowableError(getCellStr(row, colMap.get("allowableError")));
                d.setCalibrationResult(getCellStr(row, colMap.get("calibrationResult")));
                d.setRemark(getCellStr(row, colMap.get("remark")));
                d.setCreatedBy(username);

                String useStatusStr = getCellStr(row, colMap.get("useStatus"));
                if (useStatusStr != null && !useStatusStr.isBlank()) d.setUseStatus(useStatusStr);

                String cycleStr = getCellStr(row, colMap.get("cycleMonths"));
                int cycle = (cycleStr != null && !cycleStr.isBlank()) ? (int) Double.parseDouble(cycleStr) : 12;
                d.setCycle(normalizeCycle(cycle));

                String calDateStr = getCellStr(row, colMap.get("calDate"));
                if (calDateStr != null && !calDateStr.isBlank()) {
                    try { d.setCalDate(LocalDate.parse(calDateStr.trim())); } catch (Exception ignored) {}
                }
                String purchaseDateStr = getCellStr(row, colMap.get("purchaseDate"));
                if (purchaseDateStr != null && !purchaseDateStr.isBlank()) {
                    try { d.setPurchaseDate(LocalDate.parse(purchaseDateStr.trim())); } catch (Exception ignored) {}
                }
                String priceStr = getCellStr(row, colMap.get("purchasePrice"));
                if (priceStr != null && !priceStr.isBlank()) {
                    try { d.setPurchasePrice(Double.parseDouble(priceStr)); } catch (Exception ignored) {}
                }

                recalcMetrics(d, settings);
                try {
                    deviceRepository.save(d);
                    count++;
                } catch (Exception ignored) {
                    // skip duplicate or invalid rows
                }
            }
        }
        return count;
    }
    public String saveFile(MultipartFile file) throws IOException {
        File dir = new File(uploadPath);
        if (!dir.exists()) dir.mkdirs();
        String ext = "";
        String original = file.getOriginalFilename();
        if (original != null && original.contains(".")) ext = original.substring(original.lastIndexOf("."));
        String filename = UUID.randomUUID() + ext;
        File dest = new File(dir, filename);
        file.transferTo(dest);
        return "/uploads/" + filename;
    }

    public String[] calculateMetrics(LocalDate calDate, Integer cycle, int warningDays, int expiredDays) {
        if (calDate == null) return new String[]{"\u6709\u6548", "0"};
        LocalDate today = LocalDate.now();
        long daysPassed = ChronoUnit.DAYS.between(calDate, today);
        if (daysPassed < 0) daysPassed = 0;
        String validity;
        if (daysPassed >= expiredDays) validity = "\u5931\u6548";
        else if (daysPassed >= warningDays) validity = "\u5373\u5c06\u8fc7\u671f";
        else validity = "\u6709\u6548";
        return new String[]{validity, String.valueOf(daysPassed)};
    }

    private void recalcMetrics(Device d, UserSettings settings) {
        String[] metrics = calculateMetrics(d.getCalDate(), d.getCycle(),
                settings.getWarningDays(), settings.getExpiredDays());
        d.setValidity(metrics[0]);
        d.setDaysPassed(Integer.parseInt(metrics[1]));
        if (d.getCalDate() != null) {
            int cycleMonths = normalizeCycle(d.getCycle());
            d.setNextDate(d.getCalDate().plusMonths(cycleMonths).minusDays(1));
        }
    }

    DeviceDto toDto(Device d, UserSettings settings, boolean includePurchasePrice) {
        String[] metrics = calculateMetrics(d.getCalDate(), d.getCycle(),
                settings.getWarningDays(), settings.getExpiredDays());
        DeviceDto dto = new DeviceDto();
        dto.setId(d.getId());
        dto.setName(d.getName());
        dto.setMetricNo(d.getMetricNo());
        dto.setAssetNo(d.getAssetNo());
        dto.setSerialNo(d.getSerialNo());
        dto.setAbcClass(d.getAbcClass());
        dto.setDept(d.getDept());
        dto.setLocation(d.getLocation());
        dto.setCycle(d.getCycle());
        dto.setCalDate(d.getCalDate() != null ? d.getCalDate().toString() : null);
        LocalDate computedNextDate = d.getCalDate() == null
                ? null
                : d.getCalDate().plusMonths(normalizeCycle(d.getCycle())).minusDays(1);
        dto.setNextDate(computedNextDate != null ? computedNextDate.toString() : null);
        dto.setValidity(metrics[0]);
        dto.setDaysPassed(Integer.parseInt(metrics[1]));
        dto.setStatus(d.getStatus());
        dto.setRemark(d.getRemark());
        dto.setImagePath(d.getImagePath());
        dto.setImageName(d.getImageName());
        dto.setImagePath2(d.getImagePath2());
        dto.setImageName2(d.getImageName2());
        dto.setCertPath(d.getCertPath());
        dto.setCertName(d.getCertName());
        dto.setUseStatus(d.getUseStatus() != null ? d.getUseStatus() : "\u5728\u7528");
        dto.setPurchasePrice(includePurchasePrice ? d.getPurchasePrice() : null);
        dto.setPurchaseDate(d.getPurchaseDate() != null ? d.getPurchaseDate().toString() : null);
        dto.setCalibrationResult(d.getCalibrationResult());
        dto.setResponsiblePerson(d.getResponsiblePerson());
        dto.setManufacturer(d.getManufacturer());
        dto.setModel(d.getModel());
        dto.setGraduationValue(d.getGraduationValue());
        dto.setTestRange(d.getTestRange());
        dto.setAllowableError(d.getAllowableError());
        if (d.getPurchaseDate() != null) {
            long years = ChronoUnit.YEARS.between(d.getPurchaseDate(), LocalDate.now());
            dto.setServiceLife((int) Math.max(0, years));
        }
        return dto;
    }

    private Device fromDto(DeviceDto dto) {
        Device d = new Device();
        updateFromDto(d, dto);
        return d;
    }

    private void updateFromDto(Device d, DeviceDto dto) {
        if (dto.getName() != null) d.setName(dto.getName());
        if (dto.getMetricNo() != null) d.setMetricNo(dto.getMetricNo());
        if (dto.getAssetNo() != null) d.setAssetNo(dto.getAssetNo());
        if (dto.getSerialNo() != null) d.setSerialNo(dto.getSerialNo());
        if (dto.getAbcClass() != null) d.setAbcClass(dto.getAbcClass());
        if (dto.getDept() != null) d.setDept(dto.getDept());
        if (dto.getLocation() != null) d.setLocation(dto.getLocation());
        if (dto.getCycle() != null) d.setCycle(normalizeCycle(dto.getCycle()));
        if (dto.getCalDate() != null && !dto.getCalDate().isBlank()) {
            d.setCalDate(LocalDate.parse(dto.getCalDate()));
        } else { d.setCalDate(null); }
        if (dto.getPurchaseDate() != null && !dto.getPurchaseDate().isBlank()) {
            d.setPurchaseDate(LocalDate.parse(dto.getPurchaseDate()));
        } else if (dto.getPurchaseDate() != null) { d.setPurchaseDate(null); }
        if (dto.getRemark() != null) d.setRemark(dto.getRemark());
        if (dto.getStatus() != null) d.setStatus(dto.getStatus());
        if (dto.getUseStatus() != null) d.setUseStatus(dto.getUseStatus());
        if (dto.getImagePath() != null) d.setImagePath(normalizeFileField(dto.getImagePath()));
        if (dto.getImageName() != null) d.setImageName(normalizeFileField(dto.getImageName()));
        if (dto.getImagePath2() != null) d.setImagePath2(normalizeFileField(dto.getImagePath2()));
        if (dto.getImageName2() != null) d.setImageName2(normalizeFileField(dto.getImageName2()));
        if (dto.getCertPath() != null) d.setCertPath(normalizeFileField(dto.getCertPath()));
        if (dto.getCertName() != null) d.setCertName(normalizeFileField(dto.getCertName()));
        if (dto.getPurchasePrice() != null) d.setPurchasePrice(dto.getPurchasePrice());
        if (dto.getCalibrationResult() != null) d.setCalibrationResult(dto.getCalibrationResult());
        if (dto.getResponsiblePerson() != null) d.setResponsiblePerson(dto.getResponsiblePerson());
        if (dto.getManufacturer() != null) d.setManufacturer(dto.getManufacturer());
        if (dto.getModel() != null) d.setModel(dto.getModel());
        if (dto.getGraduationValue() != null) d.setGraduationValue(dto.getGraduationValue());
        if (dto.getTestRange() != null) d.setTestRange(dto.getTestRange());
        if (dto.getAllowableError() != null) d.setAllowableError(dto.getAllowableError());
    }

    private String normalizeFileField(String value) {
        if (value == null) return null;
        String normalized = value.trim();
        return normalized.isEmpty() ? null : normalized;
    }

    private String getCellStr(Row row, Integer col) {
        if (col == null || row == null) return null;
        Cell cell = row.getCell(col);
        if (cell == null) return null;
        return switch (cell.getCellType()) {
            case STRING -> {
                String s = cell.getStringCellValue().trim();
                yield s.isEmpty() ? null : s;
            }
            case NUMERIC -> {
                if (DateUtil.isCellDateFormatted(cell)) {
                    yield cell.getLocalDateTimeCellValue().toLocalDate()
                            .format(DateTimeFormatter.ISO_LOCAL_DATE);
                }
                double v = cell.getNumericCellValue();
                yield v == Math.floor(v) ? String.valueOf((long) v) : String.valueOf(v);
            }
            case FORMULA -> {
                try {
                    if (DateUtil.isCellDateFormatted(cell)) {
                        yield cell.getLocalDateTimeCellValue().toLocalDate()
                                .format(DateTimeFormatter.ISO_LOCAL_DATE);
                    }
                    double v = cell.getNumericCellValue();
                    yield v == Math.floor(v) ? String.valueOf((long) v) : String.valueOf(v);
                } catch (Exception e) {
                    String s = cell.getStringCellValue().trim();
                    yield s.isEmpty() ? null : s;
                }
            }
            default -> null;
        };
    }

    private Set<String> resolveDeptScope(String deptNames) {
        if (deptNames == null || deptNames.isBlank()) return Collections.emptySet();
        Set<String> scope = new LinkedHashSet<>();
        for (String rootName : splitDepartments(deptNames)) {
            scope.addAll(resolveSingleDeptScope(rootName));
        }
        return scope;
    }

    private Set<String> resolveSingleDeptScope(String rootName) {
        if (rootName == null || rootName.isBlank()) return Collections.emptySet();

        List<Department> all = departmentRepository.findAllByOrderBySortOrderAscNameAsc();
        if (all.isEmpty()) return new LinkedHashSet<>(Collections.singleton(rootName));

        Map<String, Department> byName = all.stream()
                .filter(d -> d.getName() != null && !d.getName().isBlank())
                .collect(Collectors.toMap(d -> normalizeDeptName(d.getName()), d -> d, (a, b) -> a, LinkedHashMap::new));
        Department root = byName.get(rootName);
        if (root == null) return new LinkedHashSet<>(Collections.singleton(rootName));

        Map<Long, Department> byId = all.stream()
                .collect(Collectors.toMap(Department::getId, d -> d, (a, b) -> a, LinkedHashMap::new));
        Map<Long, List<Department>> childrenMap = all.stream()
                .filter(d -> d.getParentId() != null)
                .collect(Collectors.groupingBy(Department::getParentId, LinkedHashMap::new, Collectors.toList()));

        Set<String> names = new LinkedHashSet<>();
        Set<Long> visited = new HashSet<>();
        Deque<Long> queue = new ArrayDeque<>();
        queue.add(root.getId());

        while (!queue.isEmpty()) {
            Long id = queue.poll();
            if (id == null || !visited.add(id)) continue;
            Department current = byId.get(id);
            if (current != null && current.getName() != null && !current.getName().isBlank()) {
                names.add(normalizeDeptName(current.getName()));
            }
            for (Department child : childrenMap.getOrDefault(id, Collections.emptyList())) {
                queue.add(child.getId());
            }
        }

        if (names.isEmpty()) names.add(rootName);
        return names;
    }

    private List<String> splitDepartments(String stored) {
        if (stored == null || stored.isBlank()) return Collections.emptyList();
        return Arrays.stream(stored.replace('，', ',').split(DEPT_SEPARATOR))
                .map(this::normalizeDeptName)
                .filter(s -> s != null && !s.isBlank())
                .distinct()
                .collect(Collectors.toList());
    }

    private Set<String> intersectScopes(Set<String> left, Set<String> right) {
        if (left == null || left.isEmpty() || right == null || right.isEmpty()) return Collections.emptySet();
        Set<String> intersection = new LinkedHashSet<>(left);
        intersection.retainAll(right);
        return intersection;
    }

    private String normalizeDeptName(String name) {
        return name == null ? null : name.trim();
    }

    private String normalizeParam(String value) {
        if (value == null) return null;
        String normalized = value.trim();
        return normalized.isEmpty() ? null : normalized;
    }

    private Map<String, Long> buildValiditySummary(String search,
                                                   String assetNo,
                                                   String serialNo,
                                                   List<String> deptScopes,
                                                   boolean deptsEmpty,
                                                   String validity,
                                                   String responsiblePerson,
                                                   String useStatus,
                                                   LocalDate nextDateFrom,
                                                   LocalDate nextDateTo,
                                                   boolean todoOnly) {
        Map<String, Long> summary = new LinkedHashMap<>();
        for (Object[] row : deviceRepository.countValiditySummary(
                search,
                assetNo,
                serialNo,
                deptScopes,
                deptsEmpty,
                validity,
                responsiblePerson,
                useStatus,
                nextDateFrom,
                nextDateTo,
                todoOnly
        )) {
            if (row == null || row.length < 2 || row[0] == null || row[1] == null) {
                continue;
            }
            summary.put(String.valueOf(row[0]), ((Number) row[1]).longValue());
        }
        return summary;
    }

    private Map<String, Long> buildUseStatusSummary(String search,
                                                    String assetNo,
                                                    String serialNo,
                                                    List<String> deptScopes,
                                                    boolean deptsEmpty,
                                                    String validity,
                                                    String responsiblePerson,
                                                    String useStatus,
                                                    LocalDate nextDateFrom,
                                                    LocalDate nextDateTo,
                                                    boolean todoOnly) {
        Map<String, Long> summary = new LinkedHashMap<>();
        for (Object[] row : deviceRepository.countUseStatusSummary(
                search,
                assetNo,
                serialNo,
                deptScopes,
                deptsEmpty,
                validity,
                responsiblePerson,
                useStatus,
                nextDateFrom,
                nextDateTo,
                todoOnly
        )) {
            if (row == null || row.length < 2 || row[1] == null) {
                continue;
            }
            String key = row[0] == null ? "其他" : String.valueOf(row[0]).trim();
            if (key.isEmpty()) key = "其他";
            summary.put(key, ((Number) row[1]).longValue());
        }
        return summary;
    }

    private LocalDate parseDate(String value) {
        String normalized = normalizeParam(value);
        return normalized == null ? null : LocalDate.parse(normalized);
    }

    private String normalizeImportHeader(String header) {
        if (header == null) return "";
        return header.trim()
                .replace("*", "")
                .replace("（YYYY-MM-DD）", "")
                .replace("(YYYY-MM-DD)", "")
                .replace("（auto）", "")
                .replace("(auto)", "")
                .replace("（自动）", "")
                .replace("(自动)", "")
                .replace("（6/12）", "")
                .replace("(6/12)", "")
                .replace("（月，6/12）", "")
                .replace("(月，6/12)", "")
                .replace("（月,6/12）", "")
                .replace("(月,6/12)", "")
                .trim();
    }

    private String toImportFieldKey(String key) {
        if (key == null || key.isBlank()) return null;
        return switch (key) {
            case "name", "设备名称" -> "name";
            case "metricNo", "计量编号" -> "metricNo";
            case "assetNo", "资产编号" -> "assetNo";
            case "serialNo", "出厂编号" -> "serialNo";
            case "abcClass", "ABC分类" -> "abcClass";
            case "dept", "使用部门" -> "dept";
            case "location", "存放地点" -> "location";
            case "manufacturer", "生产厂家" -> "manufacturer";
            case "model", "规格型号" -> "model";
            case "responsiblePerson", "责任人" -> "responsiblePerson";
            case "purchaseDate", "购置日期" -> "purchaseDate";
            case "purchasePrice", "购置价格" -> "purchasePrice";
            case "serviceLife", "使用年限" -> "serviceLife";
            case "cycleMonths", "校准周期", "校准周期(月)" -> "cycleMonths";
            case "calDate", "校准日期" -> "calDate";
            case "nextDate", "下次校准日期" -> "nextDate";
            case "validity", "有效状态" -> "validity";
            case "calibrationResult", "校准结果" -> "calibrationResult";
            case "graduationValue", "分度值" -> "graduationValue";
            case "testRange", "测量范围" -> "testRange";
            case "allowableError", "允许误差" -> "allowableError";
            case "useStatus", "使用状态" -> "useStatus";
            case "remark", "备注" -> "remark";
            default -> null;
        };
    }

    private String s(String v) { return v != null ? v : ""; }

    private int normalizeCycle(Integer cycle) {
        return (cycle != null && cycle == 6) ? 6 : 12;
    }
}
