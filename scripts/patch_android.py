"""Patches the generated Android project (run by GitHub Actions after `flutter create`)."""
import pathlib
import re

# ---------------- AndroidManifest ----------------
mp = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = mp.read_text()
perms = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
"""
s = re.sub(r'android:label="[^"]*"', 'android:label="0XDL"', s, count=1)
s = s.replace(
    "<application",
    perms + '    <application android:requestLegacyExternalStorage="true" '
    'android:usesCleartextTraffic="true" android:extractNativeLibs="true"',
    1,
)
service = '    <service android:name=".DownloadForegroundService" android:exported="false" android:foregroundServiceType="dataSync"/>\n'
s = s.replace("</application>", service + "    </application>", 1)
intent = '<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>'
if "<queries>" in s:
    s = s.replace("<queries>", "<queries>\n        " + intent, 1)
else:
    s = s.replace("</manifest>", "    <queries>\n        " + intent + "\n    </queries>\n</manifest>")
mp.write_text(s)

# ---------------- app/build.gradle(.kts) ----------------
kts = pathlib.Path("android/app/build.gradle.kts")
groovy = pathlib.Path("android/app/build.gradle")
g = kts if kts.exists() else groovy
is_kts = g.name.endswith(".kts")
text = g.read_text()

deps = """
dependencies {
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:aria2c:0.18.1")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.work:work-runtime:2.9.1")
}
"""

if is_kts:
    extra = """

// ---- 0XDL: engine (yt-dlp + ffmpeg + aria2c), release signing ----
val oxKeyFile = rootProject.file("key.properties")
val oxKeyProps = Properties()
if (oxKeyFile.exists()) {
    FileInputStream(oxKeyFile).use { oxKeyProps.load(it) }
}

android {
    defaultConfig {
        minSdk = 24
    }
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
    signingConfigs {
        create("oxRelease") {
            if (oxKeyFile.exists()) {
                keyAlias = oxKeyProps["keyAlias"] as String
                keyPassword = oxKeyProps["keyPassword"] as String
                storeFile = file(oxKeyProps["storeFile"] as String)
                storePassword = oxKeyProps["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            if (oxKeyFile.exists()) {
                signingConfig = signingConfigs.getByName("oxRelease")
            }
        }
    }
}
""" + deps
else:
    extra = """

// ---- 0XDL: engine (yt-dlp + ffmpeg + aria2c), release signing ----
def oxKeyFile = rootProject.file("key.properties")
def oxKeyProps = new Properties()
if (oxKeyFile.exists()) {
    oxKeyFile.withInputStream { oxKeyProps.load(it) }
}

android {
    defaultConfig {
        minSdk = 24
    }
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
    signingConfigs {
        oxRelease {
            if (oxKeyFile.exists()) {
                keyAlias oxKeyProps['keyAlias']
                keyPassword oxKeyProps['keyPassword']
                storeFile file(oxKeyProps['storeFile'])
                storePassword oxKeyProps['storePassword']
            }
        }
    }
    buildTypes {
        release {
            minifyEnabled false
            shrinkResources false
            if (oxKeyFile.exists()) {
                signingConfig signingConfigs.oxRelease
            }
        }
    }
}
""" + deps
g.write_text("import java.util.Properties\nimport java.io.FileInputStream\n\n" + text + extra)
print("patched", g)
