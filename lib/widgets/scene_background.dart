import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// مشهد التصميم الأصلي (1024×1536).
/// - الخلفية والعناصر بتتكبر بنفس المعامل [s] فيفضلوا متطابقين على أي شاشة.
/// - الشاشات الطويلة: المشهد بيملا الارتفاع (cover) والجوانب الفاضية بس هي اللي بتتقص،
///   وده بيخلي العناصر قريبة من بعض ومش متباعدة.
/// - لو المحتوى الأساسي (القوس → الجرس) مش هيتسع، بنصغّر لحد ما يتسع.
class SceneCanvas extends StatelessWidget {
  final List<Widget> Function(double s) childrenBuilder;
  const SceneCanvas({super.key, required this.childrenBuilder});

  static const designW = 1024.0;
  static const designH = 1536.0;
  // صندوق المحتوى الأساسي بإحداثيات التصميم (+ هامش)
  static const contentW = 660.0;
  static const contentH = 1500.0;

  /// معامل التكبير حسب مقاس المساحة المتاحة.
  static double scaleFor(double w, double h) {
    final cover = math.max(w / designW, h / designH);
    final fit = math.min(w / contentW, h / contentH);
    return math.min(cover, fit);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      // نثبّت حجم الخط داخل المشهد علشان التصميم ما يبوظش مع تكبير خط النظام
      data: mq.copyWith(textScaler: TextScaler.noScaling),
      child: LayoutBuilder(builder: (context, c) {
        // المشهد بيتحسب فوق شريط التنقل السفلي (زرار 3 أزرار) علشان ما يغطيش على «التذكير مفعل»
        final bottomInset = mq.viewPadding.bottom;
        final sceneH = math.max(0.0, c.maxHeight - bottomInset);
        final s = scaleFor(c.maxWidth, sceneH);
        return Container(
          width: c.maxWidth,
          height: c.maxHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.deepTop, AppColors.deep],
            ),
          ),
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: c.maxWidth,
            height: sceneH,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: SizedBox(
                  width: designW * s,
                  height: designH * s,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                          stops: [0, 0.05, 0.95, 1],
                        ).createShader(r),
                        blendMode: BlendMode.dstIn,
                        child: Image.asset('assets/images/background.jpg', fit: BoxFit.fill),
                      ),
                    ),
                    ...childrenBuilder(s),
                  ]),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
