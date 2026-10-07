import com.android.apksig.ApkSigner;
import com.android.apksig.ApkVerifier;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.cert.X509Certificate;
import java.util.List;

/**
 * 시험용 APK 를 업로드 키로 다시 서명한다(v2 서명). 앱 최소 안드로이드 7(SDK 24)라 v1 은 쓰지 않는다.
 * 늘 같은 키로 서명하므로, 빌드 번호가 더 큰 새 판은 지우지 않고 업데이트로 설치된다.
 *
 * <p>사용: SignApk &lt;keystore&gt; &lt;in.apk&gt; &lt;out.apk&gt;
 * 비밀번호·별칭은 환경변수 ALKKAGI_KEYSTORE_PASSWORD · ALKKAGI_KEY_PASSWORD · ALKKAGI_KEY_ALIAS.
 */
public class SignApk {
  public static void main(String[] a) throws Exception {
    String alias = System.getenv("ALKKAGI_KEY_ALIAS");
    KeyStore ks = KeyStore.getInstance(KeyStore.getDefaultType());
    try (InputStream in = new FileInputStream(a[0])) {
      ks.load(in, System.getenv("ALKKAGI_KEYSTORE_PASSWORD").toCharArray());
    }
    PrivateKey key =
        (PrivateKey) ks.getKey(alias, System.getenv("ALKKAGI_KEY_PASSWORD").toCharArray());
    X509Certificate cert = (X509Certificate) ks.getCertificate(alias);
    ApkSigner.SignerConfig sc =
        new ApkSigner.SignerConfig.Builder("UPLOAD", key, List.of(cert)).build();
    new ApkSigner.Builder(List.of(sc))
        .setInputApk(new File(a[1]))
        .setOutputApk(new File(a[2]))
        .setMinSdkVersion(24)
        .setV1SigningEnabled(false)
        .setV2SigningEnabled(true)
        .build()
        .sign();

    ApkVerifier.Result r = new ApkVerifier.Builder(new File(a[2])).build().verify();
    System.out.println("검증=" + r.isVerified() + " v2=" + r.isVerifiedUsingV2Scheme());
    for (var e : r.getErrors()) System.out.println("오류 " + e);
    for (var c : r.getSignerCertificates()) {
      byte[] d = MessageDigest.getInstance("SHA-256").digest(c.getEncoded());
      StringBuilder sb = new StringBuilder();
      for (byte b : d) sb.append(String.format("%02X:", b));
      System.out.println("서명 인증서 SHA-256 " + sb.substring(0, sb.length() - 1));
    }
    if (!r.isVerified()) System.exit(1);
  }
}
