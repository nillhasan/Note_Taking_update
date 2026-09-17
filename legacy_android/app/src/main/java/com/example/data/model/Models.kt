package com.example.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class UserProfile(
    val id: String = "guest_user",
    val name: String = "Demo User",
    val email: String = "user@noteflow.ai",
    val photoUrl: String? = null,
    val isAnonymous: Boolean = false,
    val authProvider: String = "supabase_email", // supabase_google, supabase_apple, supabase_email, supabase_passkey, guest
    val supabaseId: String? = null,
    val stripeCustomerId: String? = null,
    val subscriptionTierName: String = "EXECUTIVE_PRO",
    val createdAt: Long = System.currentTimeMillis()
)

@JsonClass(generateAdapter = true)
data class TranscriptSegment(
    val speaker: String = "Speaker 1",
    val timestamp: String = "00:00",
    val text: String = ""
)

@Entity(tableName = "notes")
@JsonClass(generateAdapter = true)
data class NoteEntity(
    @PrimaryKey
    val id: String,
    val userId: String,
    val title: String,
    val type: String = "VOICE", // VOICE, MEETING, TEXT, IMPORT
    val audioPath: String? = null,
    val durationSec: Int = 0,
    val status: String = "COMPLETED", // RECORDING, PROCESSING, TRANSCRIBING, ANALYZING, COMPLETED, ERROR
    val folder: String = "All",
    val tags: List<String> = emptyList(),
    val transcriptText: String = "",
    val transcriptSegments: List<TranscriptSegment> = emptyList(),
    val summaryShort: String = "",
    val summaryDetailed: String = "",
    val summaryBullets: List<String> = emptyList(),
    val meetingMinutes: String = "",
    val decisions: List<String> = emptyList(),
    val risks: List<String> = emptyList(),
    val isFavorite: Boolean = false,
    val isArchived: Boolean = false,
    val isDeleted: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val syncStatus: String = "SYNCED" // SYNCED, PENDING_PUSH, LOCAL_ONLY
)

@Entity(tableName = "action_items")
@JsonClass(generateAdapter = true)
data class ActionItemEntity(
    @PrimaryKey
    val id: String,
    val noteId: String,
    val userId: String,
    val task: String,
    val owner: String = "Unassigned",
    val dueDate: String = "",
    val isCompleted: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val syncStatus: String = "SYNCED"
)

@Entity(tableName = "folders")
@JsonClass(generateAdapter = true)
data class FolderEntity(
    @PrimaryKey
    val id: String,
    val userId: String,
    val name: String,
    val colorHex: String = "#2563EB",
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "email_activities")
@JsonClass(generateAdapter = true)
data class EmailActivityRecord(
    @PrimaryKey
    val id: String,
    val noteId: String,
    val userId: String,
    val recipients: String,
    val contentType: String,
    val subject: String,
    val sentAt: Long = System.currentTimeMillis()
)

enum class SubscriptionTier(
    val title: String,
    val badge: String,
    val monthlyPrice: String,
    val annualPrice: String,
    val description: String,
    val isPopular: Boolean = false,
    val features: List<String>
) {
    STARTER(
        title = "Free Starter",
        badge = "Basic Tier",
        monthlyPrice = "$0",
        annualPrice = "$0",
        description = "Standard personal speech notes and on-device recording",
        isPopular = false,
        features = listOf(
            "3 voice notes / day",
            "On-device speech transcription",
            "Local offline storage (Room DB)",
            "Basic text search & tags"
        )
    ),
    EXECUTIVE_PRO(
        title = "Executive Pro",
        badge = "Most Popular",
        monthlyPrice = "$19",
        annualPrice = "$15",
        description = "Full executive voice intelligence, minutes & task extraction",
        isPopular = true,
        features = listOf(
            "Unlimited voice & meeting recordings",
            "Gemini 2.5 Flash live meeting minutes",
            "Automated action item extraction & tasks checklist",
            "Real-time Firestore cloud sync across devices",
            "Interactive voice note grounded Q&A chat",
            "High-fidelity waveform audio scrub & playback"
        )
    ),
    ENTERPRISE_SUITE(
        title = "Enterprise Suite",
        badge = "Maximum Security",
        monthlyPrice = "$49",
        annualPrice = "$39",
        description = "Advanced security, SSO/SAML 2.0 & hardware enclave",
        isPopular = false,
        features = listOf(
            "Everything in Executive Pro",
            "SOC2 Type II Certified Zero-Knowledge Vault",
            "Enterprise SSO / SAML 2.0 & Passkey Enclave",
            "FaceID / TouchID biometric session lock",
            "Multi-speaker diarization & priority AI pipeline",
            "Team knowledge base synchronization"
        )
    );

    fun getPriceCents(isAnnual: Boolean): Long {
        return when (this) {
            STARTER -> 0L
            EXECUTIVE_PRO -> if (isAnnual) 18000L else 1900L // $180/yr ($15/mo) or $19/mo
            ENTERPRISE_SUITE -> if (isAnnual) 46800L else 4900L // $468/yr ($39/mo) or $49/mo
        }
    }

    fun getPriceDisplay(isAnnual: Boolean): String {
        return when (this) {
            STARTER -> "$0"
            EXECUTIVE_PRO -> if (isAnnual) "$15" else "$19"
            ENTERPRISE_SUITE -> if (isAnnual) "$39" else "$49"
        }
    }
}

@JsonClass(generateAdapter = true)
data class StripePaymentReceipt(
    val paymentIntentId: String,
    val customerEmail: String,
    val amountPaidFormatted: String,
    val currency: String = "USD",
    val cardBrand: String,
    val cardLast4: String,
    val tierTitle: String,
    val billingCycle: String,
    val timestamp: Long = System.currentTimeMillis(),
    val status: String = "succeeded",
    val receiptUrl: String? = null
)
