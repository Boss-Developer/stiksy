# Release shrinking rules (R8 / ProGuard). Flutter's own, and each plugin's
# (AdMob, Play Billing, Supabase and so on), are added automatically.

# Readable crash reports once the mapping file is uploaded to Play Console.
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,InnerClasses,EnclosingMethod
-renamesourcefileattribute SourceFile

# WhatsApp finds the sticker provider by name and reads these columns by name,
# so it must keep its class name and members.
-keep class com.sfdevelopers.stiksy.StickerContentProvider { *; }
-keep class com.sfdevelopers.stiksy.StickerStore { *; }
-keep class com.sfdevelopers.stiksy.MainActivity { *; }

# Flutter references Play Core only for deferred components, which this app does not use.
-dontwarn com.google.android.play.core.**

# ---- Keep rules to avoid release-only crashes -------------------------------
# Flutter engine and plugin glue (looked up by name through JNI and registrants).
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Plugins this app uses.
-keep class com.android.billingclient.** { *; }                 # in_app_purchase (Play Billing)
-keep class io.flutter.plugins.inapppurchase.** { *; }
-keep class com.google.android.gms.ads.** { *; }                # google_mobile_ads
-keep class io.flutter.plugins.googlemobileads.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }        # flutter_secure_storage
-keep class dev.fluttercommunity.plus.** { *; }                 # share_plus, package_info_plus
-keep class com.baseflow.permissionhandler.** { *; }            # permission_handler
-keep class io.flutter.plugins.imagepicker.** { *; }            # image_picker
-keep class io.flutter.plugins.pathprovider.** { *; }           # path_provider
-keep class io.flutter.plugins.sharedpreferences.** { *; }      # shared_preferences
-keep class io.flutter.plugins.urllauncher.** { *; }            # url_launcher
-dontwarn com.google.android.gms.**

# Everything that crosses the Flutter method channel or is read by name.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepclasseswithmembernames class * { native <methods>; }
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keepclassmembers class * implements java.io.Serializable {
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Kotlin
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# Room (used by WorkManager, which AdMob starts at launch) creates its database
# by reflection through the generated *_Impl class and its no-argument constructor.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class androidx.startup.** { *; }
-keep class * extends androidx.startup.Initializer { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.paging.**

# Don't let R8 remove code that is only reached by reflection or from the manifest.
-keep public class * extends android.app.Application
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.app.Service

# Shrink and obfuscate, but skip R8's code optimisations: they are the usual
# source of release-only crashes and give little benefit for this app.
-dontoptimize
