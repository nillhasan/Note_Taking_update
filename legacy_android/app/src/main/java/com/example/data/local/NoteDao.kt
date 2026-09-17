package com.example.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.example.data.model.NoteEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface NoteDao {
    @Query("SELECT * FROM notes WHERE userId = :userId AND isDeleted = 0 AND isArchived = 0 ORDER BY createdAt DESC")
    fun getActiveNotes(userId: String): Flow<List<NoteEntity>>

    @Query("SELECT * FROM notes WHERE userId = :userId AND isFavorite = 1 AND isDeleted = 0 AND isArchived = 0 ORDER BY createdAt DESC")
    fun getFavoriteNotes(userId: String): Flow<List<NoteEntity>>

    @Query("SELECT * FROM notes WHERE userId = :userId AND isArchived = 1 AND isDeleted = 0 ORDER BY createdAt DESC")
    fun getArchivedNotes(userId: String): Flow<List<NoteEntity>>

    @Query("SELECT * FROM notes WHERE userId = :userId AND isDeleted = 1 ORDER BY updatedAt DESC")
    fun getDeletedNotes(userId: String): Flow<List<NoteEntity>>

    @Query("SELECT * FROM notes WHERE id = :id")
    fun getNoteById(id: String): Flow<NoteEntity?>

    @Query("SELECT * FROM notes WHERE id = :id")
    suspend fun getNoteByIdOnce(id: String): NoteEntity?

    @Query("SELECT * FROM notes WHERE userId = :userId AND syncStatus != 'SYNCED'")
    suspend fun getPendingSyncNotes(userId: String): List<NoteEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOrUpdate(note: NoteEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(notes: List<NoteEntity>)

    @Update
    suspend fun update(note: NoteEntity)

    @Query("DELETE FROM notes WHERE id = :id")
    suspend fun hardDeleteNote(id: String)

    @Query("""
        SELECT * FROM notes 
        WHERE userId = :userId AND isDeleted = 0 
        AND (title LIKE '%' || :query || '%' 
             OR transcriptText LIKE '%' || :query || '%' 
             OR summaryShort LIKE '%' || :query || '%'
             OR meetingMinutes LIKE '%' || :query || '%')
        ORDER BY createdAt DESC
    """)
    fun searchNotes(userId: String, query: String): Flow<List<NoteEntity>>
}
