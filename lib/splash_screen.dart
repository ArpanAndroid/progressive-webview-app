import 'package:flutter/material.dart';
import 'remote_config_service.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashComplete;

  const SplashScreen({
    super.key,
    required this.onSplashComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    RemoteConfigService.initOrValidateSession();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();

    // Auto navigate after splash duration (1 second)
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        widget.onSplashComplete();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF090D16),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    children: [
                      const Spacer(),
                      // Cricket Batting Hero Graphic Card
                      Container(
                        width: size.width * 0.82,
                        height: size.height * 0.42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.35),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/images/cricket_splash.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: const Color(0xFF1E293B),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.sports_cricket, size: 72, color: Colors.blueAccent),
                                        SizedBox(height: 12),
                                        Text('Cricket Live Action', style: TextStyle(color: Colors.white, fontSize: 18)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              // Vibrant gradient tint at bottom of artwork
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.4),
                                        Colors.black.withOpacity(0.85),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Overlay Badge
                              Positioned(
                                bottom: 16,
                                left: 16,
                                right: 16,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.amberAccent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'LIVE',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Cricket Batting App',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // App Title & Tagline
                      const Text(
                        'STABLES 365',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 14, color: Colors.greenAccent),
                            SizedBox(width: 6),
                            Text(
                              '72-Hour Session Persistence Active',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Sleek Bottom Loading Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: const SizedBox(
                                height: 4,
                                child: LinearProgressIndicator(
                                  backgroundColor: Color(0xFF334155),
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Initializing WebView Engine...',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
