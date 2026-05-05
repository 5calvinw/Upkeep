# Taste (Continuously Learned by [CommandCode][cmd])

[cmd]: https://commandcode.ai/

# Flutter
- Do not use IntrinsicHeight/IntrinsicWidth when the subtree contains a ListView, GridView, or any Viewport-based lazy-rendering widget — intrinsic dimension APIs require instantiating every child, defeating viewport laziness. Use layout constraints or fixed dimensions instead. Confidence: 0.85

