/// رابط تحميل التطبيق: ده اللي بيتشارك في «مشاركة التطبيق»، وبيتضاف في آخر مشاركة الأدعية والأذكار.
/// (لو نزّلت إصدار جديد على GitHub غيّر `v1.0.0` في الرابط، أو استخدم `releases/latest/download/` علشان يفضل ثابت.)
const String kAppLink =
    'https://github.com/AbdallahHamdy0/Salli-Ala-Muhammad/releases/download/v1.0.0/salli-ala-muhammad.apk';

String withAppLink(String text) => kAppLink.isEmpty ? text : '$text\n\n$kAppLink';

/// الفترة الافتراضية للتذكير الصوتي (بالدقايق) لأول تشغيل. لازم تكون واحدة من القايمة في الشاشة الرئيسية.
const int kDefaultIntervalMinutes = 15;

/// فترة الأذكار العشوائية بالدقايق (دلوقتي نص ساعة). غيّر الرقم وخلاص.
const int kAdhkarIntervalMinutes = 30;

/// أذكار الصباح والمساء: ميعاد التنبيه اليومي (بتوقيت الموبايل، نظام 24 ساعة).
const int kMorningHour = 7, kMorningMinute = 30;
const int kEveningHour = 19, kEveningMinute = 0;

/// تذكير تاني لو المستخدم ما فتحش الأذكار (بالدقايق). 0 = من غير تذكير تاني.
const int kDailyFollowUpMinutes = 30;

/// 19:00 → «7:00 م»
String formatClock(int hour, int minute) {
  final period = hour < 12 ? 'ص' : 'م';
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$h:${minute.toString().padLeft(2, '0')} $period';
}
