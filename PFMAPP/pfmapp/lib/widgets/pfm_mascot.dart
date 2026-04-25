import 'package:flutter/material.dart';

class PFMMascot extends StatelessWidget {
  const PFMMascot({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // jar body
          Container(
            width: 170,
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFF8E6CFF).withOpacity(0.90),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),

          // jar lid
          Positioned(
            top: 18,
            child: Container(
              width: 130,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF6B46FF),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // face
          Positioned(
            top: 60,
            child: Row(children: [_Eye(), const SizedBox(width: 14), _Eye()]),
          ),
          Positioned(
            top: 98,
            child: Container(
              width: 46,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // coins inside jar
          Positioned(
            bottom: 20,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(10, (_) => _TinyCoin()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Align(
        alignment: const Alignment(0.2, -0.2),
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _TinyCoin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFC107),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.22),
          ),
        ),
      ),
    );
  }
}
