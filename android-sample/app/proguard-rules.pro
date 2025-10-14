# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /sdk/tools/proguard/proguard-android.txt

# Keep JavaScript interface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

-keepattributes JavascriptInterface
-keepattributes *Annotation*

-dontwarn com.check24.bridgesample.**
-keep class com.check24.bridgesample.** { *; }

