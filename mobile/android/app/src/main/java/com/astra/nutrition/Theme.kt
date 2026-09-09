package com.astra.nutrition

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object AstraTheme {
    val blue = Color(0xFFE8732A)
    val blueDark = Color(0xFFFF9A5F)
    val green = Color(0xFFE8732A)
    val greenDark = Color(0xFFFF9A5F)
    val amber = Color(0xFFE8732A)
    val ink = Color(0xFF1A1A1A)
    val inkDark = Color(0xFFF7F4F0)
    val muted = Color(0xFFA09E9B)
    val mutedDark = Color(0xFFB8B0A9)
    val canvas = Color(0xFFFFFFFF)
    val canvasDark = Color(0xFF121110)
    val surface = Color(0xFFFFFFFF)
    val surfaceDark = Color(0xFF1C1A18)
    val surfaceElevatedDark = Color(0xFF25221F)
    val line = Color(0xFFF0EEEA)
    val lineDark = Color(0xFF3A332E)
    val danger = Color(0xFFFF3B30)
}

private val lightColors = lightColorScheme(
    primary = AstraTheme.blue,
    secondary = AstraTheme.blue,
    background = AstraTheme.canvas,
    surface = AstraTheme.surface,
    surfaceVariant = AstraTheme.line,
    outline = AstraTheme.line,
    onBackground = AstraTheme.ink,
    onSurface = AstraTheme.ink,
    onSurfaceVariant = AstraTheme.muted
)

private val darkColors = darkColorScheme(
    primary = AstraTheme.blueDark,
    secondary = AstraTheme.blueDark,
    background = AstraTheme.canvasDark,
    surface = AstraTheme.surfaceDark,
    surfaceVariant = AstraTheme.surfaceElevatedDark,
    outline = AstraTheme.lineDark,
    onBackground = AstraTheme.inkDark,
    onSurface = AstraTheme.inkDark,
    onSurfaceVariant = AstraTheme.mutedDark
)

@Composable
fun AstraTheme(darkTheme: Boolean = false, content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (darkTheme) darkColors else lightColors,
        typography = Typography(),
        content = content
    )
}
