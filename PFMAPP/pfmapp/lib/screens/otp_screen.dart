import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/floating_coins.dart';
import '../services/pffm_api.dart';
import '../services/session.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String name;

  const OtpScreen({super.key, required this.email, required this.name});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int otpLen = 6;

  final List<TextEditingController> _controllers = List.generate(
    otpLen,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(otpLen, (_) => FocusNode());

  bool _loading = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final otp = _otp;

    if (otp.length != otpLen || otp.contains(RegExp(r'[^0-9]'))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter all 6 digits ❗")));
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await PffmApi.verifyOtp(
        email: widget.email,
        otp: otp,
        name: widget.name,
      );

      // Backend usually returns: { ok: true, user: {...} }
      final user =
          (result["user"] as Map?)?.cast<String, dynamic>() ??
          {"email": widget.email, "name": widget.name};
      await Session.addRegisteredUser(email: widget.email, name: widget.name);
      await Session.saveUser(user);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Verified ✅")));

      // Go to dashboard directly (or /welcome if you want)
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("OTP error: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgBase = Color(0xFFFFC9DA);

    return Scaffold(
      backgroundColor: bgBase,
      body: Stack(
        children: [
          const Positioned.fill(child: _LoginPinkGlow()),
          const Positioned.fill(child: FloatingCoins(count: 18)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFBFA7FF), Color(0xFF8F7BFF)],
                      ),
                      border: Border.all(
                        color: const Color.fromRGBO(255, 255, 255, 0.35),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 35,
                          offset: Offset(0, 18),
                          color: Color.fromRGBO(120, 80, 255, 0.25),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "OTP Verification ✨",
                          style: GoogleFonts.baloo2(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "We sent a code to:",
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.email,
                          style: GoogleFonts.baloo2(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 26),

                        // OTP boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(otpLen, (index) {
                            return SizedBox(
                              width: 52,
                              height: 62,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: TextField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 1,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                  onChanged: (v) {
                                    if (v.isNotEmpty && index < otpLen - 1) {
                                      _focusNodes[index + 1].requestFocus();
                                    }
                                    if (v.isEmpty && index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                  },
                                  decoration: InputDecoration(
                                    counterText: "",
                                    filled: true,
                                    fillColor: const Color.fromRGBO(
                                      255,
                                      255,
                                      255,
                                      0.18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 26),

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFE06B), Color(0xFFFFC928)],
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  blurRadius: 18,
                                  offset: Offset(0, 10),
                                  color: Color.fromRGBO(0, 0, 0, 0.18),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: _loading ? null : _verifyOtp,
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : Text(
                                      "Confirm",
                                      style: GoogleFonts.baloo2(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF1E1E1E),
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.pop(context),
                          child: Text(
                            "Back",
                            style: GoogleFonts.baloo2(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginPinkGlow extends StatelessWidget {
  const _LoginPinkGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.25),
          radius: 1.15,
          colors: [Color.fromRGBO(255, 255, 255, 0.92), Color(0xFFFFC9DA)],
        ),
      ),
    );
  }
}
