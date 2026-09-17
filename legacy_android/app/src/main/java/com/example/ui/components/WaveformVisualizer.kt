package com.example.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.ui.theme.NoteFlowPrimaryLight
import com.example.ui.theme.NoteFlowSecondaryDark

@Composable
fun WaveformVisualizer(
    amplitudes: List<Float>,
    modifier: Modifier = Modifier,
    isRecording: Boolean = true,
    barColor: Color = MaterialTheme.colorScheme.primary
) {
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(80.dp)
    ) {
        val width = size.width
        val height = size.height
        val totalBars = 36
        val barSpacing = 4.dp.toPx()
        val barWidth = ((width - (totalBars - 1) * barSpacing) / totalBars).coerceAtLeast(2.dp.toPx())

        // Pad or sample amplitudes to exactly totalBars
        val paddedAmplitudes = if (amplitudes.isEmpty()) {
            List(totalBars) { 0.12f }
        } else if (amplitudes.size < totalBars) {
            val missing = totalBars - amplitudes.size
            List(missing) { 0.12f } + amplitudes
        } else {
            amplitudes.takeLast(totalBars)
        }

        val centerY = height / 2f

        paddedAmplitudes.forEachIndexed { index, amp ->
            val x = index * (barWidth + barSpacing)
            val barHeight = (amp * (height * 0.88f)).coerceIn(6.dp.toPx(), height * 0.92f)
            val topY = centerY - (barHeight / 2f)

            drawRoundRect(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        barColor.copy(alpha = 0.95f),
                        NoteFlowSecondaryDark.copy(alpha = 0.75f)
                    ),
                    startY = topY,
                    endY = topY + barHeight
                ),
                topLeft = Offset(x, topY),
                size = Size(barWidth, barHeight),
                cornerRadius = CornerRadius(barWidth / 2f, barWidth / 2f)
            )
        }
    }
}
