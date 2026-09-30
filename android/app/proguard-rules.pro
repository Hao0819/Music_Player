# youtubedl-android unzips its Python and FFmpeg payloads with commons-compress,
# whose ExtraFieldUtils registers field types reflectively in a static block.
# Without this, R8 sees classes like AsiExtraField as never instantiated, makes
# them non-concrete, and the unzip dies with
#   RuntimeException: class ... is not a concrete class
-keep class org.apache.commons.compress.** { *; }
-dontwarn org.apache.commons.compress.**

# The library parses yt-dlp's JSON output into model classes via reflection.
-keep class com.yausername.youtubedl_android.** { *; }
-keep class com.yausername.ffmpeg.** { *; }
-dontwarn com.yausername.**

-keep class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.**

-keep class org.apache.commons.io.** { *; }
-dontwarn org.apache.commons.io.**

-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
