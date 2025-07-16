import 'package:flutter/material.dart';

// Premium color palette
const Color kAccentBlue  = Color(0xFFB3E5FC); // Burned card
const Color kAccentGreen = Color(0xFFC8E6C9); // Remaining card
const Color kAccentGold  = Color(0xFFFFF9C4); // Consumed card
const Color kAccentTeal  = Color(0xFFB2DFDB); // Streak card
const Color kSoftWhite   = Color(0xFFF9F9F9); // Card backgrounds
const Color kTextDark    = Color(0xFF222222);
const Color kTextGrey    = Color(0xFF888888);

// Premium gradient for backgrounds
const LinearGradient kPremiumBackgroundGradient = LinearGradient(
  colors: [
    Color(0xFFFFFFFF),
    Color(0xFFE0C3FC),
    Color(0xFFB2FEFA),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
); 