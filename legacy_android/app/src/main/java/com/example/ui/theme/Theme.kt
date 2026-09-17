package com.example.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

private val DarkColorScheme = darkColorScheme(
    primary = NoteFlowPrimaryDark,
    onPrimary = NoteFlowOnPrimaryDark,
    primaryContainer = NoteFlowPrimaryContainerDark,
    onPrimaryContainer = NoteFlowOnPrimaryContainerDark,
    secondary = NoteFlowSecondaryDark,
    onSecondary = NoteFlowOnSecondaryDark,
    secondaryContainer = NoteFlowSecondaryContainerDark,
    onSecondaryContainer = NoteFlowOnSecondaryContainerDark,
    tertiary = NoteFlowTertiaryDark,
    onTertiary = NoteFlowOnTertiaryDark,
    background = NoteFlowBackgroundDark,
    surface = NoteFlowSurfaceDark,
    surfaceVariant = NoteFlowSurfaceVariantDark,
    onBackground = NoteFlowOnSurfaceDark,
    onSurface = NoteFlowOnSurfaceDark,
    onSurfaceVariant = NoteFlowOnSurfaceVariantDark,
    outline = NoteFlowOutlineDark
)

private val LightColorScheme = lightColorScheme(
    primary = NoteFlowPrimaryLight,
    onPrimary = NoteFlowOnPrimaryLight,
    primaryContainer = NoteFlowPrimaryContainerLight,
    onPrimaryContainer = NoteFlowOnPrimaryContainerLight,
    secondary = NoteFlowSecondaryLight,
    onSecondary = NoteFlowOnSecondaryLight,
    secondaryContainer = NoteFlowSecondaryContainerLight,
    onSecondaryContainer = NoteFlowOnSecondaryContainerLight,
    tertiary = NoteFlowTertiaryLight,
    onTertiary = NoteFlowOnTertiaryLight,
    background = NoteFlowBackgroundLight,
    surface = NoteFlowSurfaceLight,
    surfaceVariant = NoteFlowSurfaceVariantLight,
    onBackground = NoteFlowOnSurfaceLight,
    onSurface = NoteFlowOnSurfaceLight,
    onSurfaceVariant = NoteFlowOnSurfaceVariantLight,
    outline = NoteFlowOutlineLight
)

@Composable
fun MyApplicationTheme(
    darkTheme: Boolean = true,
    dynamicColor: Boolean = false, // Set to false to maintain our custom NoteFlow AI branding
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
