package com.astra.nutrition

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object AstraTheme {
    val blue = Color(0xFF6F82FF)
    val blueDark = Color(0xFF8A99FF)
    val green = Color(0xFF329A63)
    val greenDark = Color(0xFF7DDBA8)
    val ink = Color(0xFF172033)
    val inkDark = Color(0xFFF4F7FC)
    val muted = Color(0xFF7D879B)
    val mutedDark = Color(0xFFAAB6C8)
    val canvas = Color(0xFFF6F8FC)
    val canvasDark = Color(0xFF0E1728)
    val surface = Color(0xFFFFFFFF)
    val surfaceDark = Color(0xFF17243A)
    val surfaceElevatedDark = Color(0xFF1E2B42)
    val line = Color(0xFFE5EAF2)
    val lineDark = Color(0xFF2A3A51)
}

private val lightColors = lightColorScheme(
    primary = AstraTheme.blue,
    secondary = AstraTheme.green,
    background = AstraTheme.canvas,
    surface = AstraTheme.surface,
    onBackground = AstraTheme.ink,
    onSurface = AstraTheme.ink
)

private val darkColors = darkColorScheme(
    primary = AstraTheme.blueDark,
    secondary = AstraTheme.greenDark,
    background = AstraTheme.canvasDark,
    surface = AstraTheme.surfaceDark,
    surfaceVariant = AstraTheme.surfaceElevatedDark,
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
