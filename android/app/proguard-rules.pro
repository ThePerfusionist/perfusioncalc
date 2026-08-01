# ProGuard / R8 rules for PerfusionCalc release builds
# =====================================================
#
# NOTE (since flutter_local_notifications 19.0.0): the plugin bumped its GSON
# dependency to 2.12, which ships its own consumer rules. The plugin's readme
# now states these rules are no longer required. They are kept here anyway
# because they are harmless, and because a silently broken SCHEDULED
# notification in a release build is expensive to diagnose - see the history
# below.
#
# WHY THIS FILE EXISTS
# Release builds run R8, which shrinks and obfuscates the bytecode. Without
# the rules below, scheduled notifications crashed the app the moment they
# fired, with:
#
#   java.lang.RuntimeException: Missing type parameter.
#       at q0.a.<init>(SourceFile:10)
#       at com.dexterous.flutterlocalnotifications
#              .ScheduledNotificationReceiver.onReceive(SourceFile:111)
#
# flutter_local_notifications persists the details of a scheduled
# notification as JSON and deserialises it in the broadcast receiver using
# Gson's TypeToken. TypeToken reads the GENERIC type argument at runtime -
# information R8 discards by default, which is exactly what "Missing type
# parameter" means.
#
# This is also why the immediate "test" notification worked while scheduled
# ones crashed: showing a notification straight away never goes through
# that JSON round-trip.
#
# The `-keepattributes Signature` line below is the one that actually fixes
# it; the rest keeps Gson and the plugin's model classes intact so the
# deserialised objects still match their declared types.

# ── Retain generic signatures and annotations (required by Gson) ───────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ── Gson ──────────────────────────────────────────────────────────────────
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
# Fields of serialised model classes must keep their names, otherwise the
# JSON written before an update no longer maps onto the obfuscated fields.
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ── flutter_local_notifications ───────────────────────────────────────────
# Its model classes are (de)serialised reflectively by Gson.
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**
