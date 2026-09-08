package com.astra.nutrition

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object AstraTheme {
    val blue = Color(0xFF6F82FF)
    val green = Color(0xFF329A63)
    val muted = Color(0xFF737E92)
    val canvas = Color(0xFFF5F7F8)
}

private val colors = lightColorScheme(primary = AstraTheme.blue, secondary = AstraTheme.green, background = AstraTheme.canvas, surface = Color.White)

@Composable
fun AstraTheme(content: @Composable () -> Unit) { MaterialTheme(colorScheme = colors, content = content) }
