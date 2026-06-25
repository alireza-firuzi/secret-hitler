import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialSlide> _slides = [
    TutorialSlide(
      title: 'نقش‌ها در بازی',
      icon: Icons.group,
      content: '''
در ابتدای بازی، هر بازیکن به صورت تصادفی و مخفیانه یک نقش دریافت می‌کند:

• لیبرال‌ها (Liberals): اکثریت بازیکنان را تشکیل می‌دهند اما همدیگر را نمی‌شناسند.
• فاشیست‌ها (Fascists): در اقلیت هستند اما همدیگر را می‌شناسند و تلاش می‌کنند هیتلر را به قدرت برسانند.
• هیتلر مخفی (Secret Hitler): عضو فاشیست‌هاست، اما یار‌های خود را نمی‌شناسد! فاشیست‌ها باید او را راهنمایی کنند.
''',
    ),
    TutorialSlide(
      title: 'روند انتخابات',
      icon: Icons.how_to_vote,
      content: '''
هر دور از بازی با انتخابات شروع می‌شود:

۱. کاندیدای ریاست‌جمهوری: نقش رئیس‌جمهور در هر دور به نفر بعدی می‌رسد.
۲. معرفی صدراعظم: کاندیدای ریاست‌جمهوری باید یک نفر را به عنوان صدراعظم معرفی کند.
۳. رای‌گیری: همه بازیکنان با Ja! (موافق) یا Nein (مخالف) رای می‌دهند.
۴. اگر رای اکثریت مثبت باشد، دولت تشکیل می‌شود و به مرحله قانون‌گذاری می‌رویم. اگر رای نیاورد، نوبت رئیس‌جمهور بعدی است.
''',
    ),
    TutorialSlide(
      title: 'مرحله قانون‌گذاری',
      icon: Icons.gavel,
      content: '''
دولت تشکیل شده باید یک سیاست جدید تصویب کند:

۱. رئیس‌جمهور ۳ کارت سیاست (فاشیست یا لیبرال) را از روی دسته کارت‌ها برمی‌دارد.
۲. او به صورت مخفیانه یکی را می‌سوزاند (Discard) و ۲ کارت دیگر را به صدراعظم می‌دهد.
۳. صدراعظم از بین آن ۲ کارت، یکی را می‌سوزاند و کارت دیگر را به عنوان قانون تصویب می‌کند و روی بورد بازی قرار می‌دهد.
''',
    ),
    TutorialSlide(
      title: 'قدرت‌های ویژه',
      icon: Icons.flash_on,
      content: '''
هنگامی که سیاست‌های فاشیستی بیشتری تصویب می‌شود، رئیس‌جمهور قدرت‌های ویژه‌ای به دست می‌آورد که باید بلافاصله از آن‌ها استفاده کند:

• بررسی وفاداری: نقش یک بازیکن را به صورت مخفیانه می‌بیند.
• پیش‌بینی (Policy Peek): سه کارت بعدی دسته سیاست‌ها را مخفیانه می‌بیند.
• انتخابات ویژه: رئیس‌جمهور دور بعدی را خودش انتخاب می‌کند.
• اعدام (Execution): یک بازیکن را از بازی حذف می‌کند!
''',
    ),
    TutorialSlide(
      title: 'شرایط پیروزی',
      icon: Icons.emoji_events,
      content: '''
بازی به دو صورت ممکن است به پایان برسد:

پیروزی لیبرال‌ها:
• ۵ قانون لیبرال تصویب شود.
• هیتلر مخفی اعدام شود!

پیروزی فاشیست‌ها:
• ۶ قانون فاشیست تصویب شود.
• پس از تصویب حداقل ۳ قانون فاشیستی، هیتلر به عنوان صدراعظم انتخاب شود!
''',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF151211),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/wood_table_background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Container(color: Colors.black.withOpacity(0.6)), // Dark overlay
              Column(
                children: [
                  const SizedBox(height: 50),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFFD4AF37)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'آموزش بازی',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE6DFD3),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance for back button
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Page View
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount: _slides.length,
                      itemBuilder: (context, index) {
                        final slide = _slides[index];
                        return _buildSlideCard(slide);
                      },
                    ),
                  ),
                  // Bottom controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _currentPage > 0
                            ? TextButton(
                                onPressed: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: const Text(
                                  'قبلی',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                              )
                            : const SizedBox(width: 60),
                        
                        // Dots indicator
                        Row(
                          children: List.generate(
                            _slides.length,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentPage == index ? 12 : 8,
                              height: _currentPage == index ? 12 : 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentPage == index
                                    ? const Color(0xFFD4AF37)
                                    : Colors.white24,
                              ),
                            ),
                          ),
                        ),

                        _currentPage < _slides.length - 1
                            ? TextButton(
                                onPressed: () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: const Text(
                                  'بعدی',
                                  style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              )
                            : TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'پایان',
                                  style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlideCard(TutorialSlide slide) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xE6251E1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4AF37).withOpacity(0.4),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF151211),
                border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
              ),
              child: Icon(slide.icon, size: 60, color: const Color(0xFFD4AF37)),
            ),
            const SizedBox(height: 32),
            Text(
              slide.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE6DFD3),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  slide.content,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.8,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TutorialSlide {
  final String title;
  final IconData icon;
  final String content;

  TutorialSlide({
    required this.title,
    required this.icon,
    required this.content,
  });
}
