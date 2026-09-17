package com.example.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.example.data.model.ActionItemEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ActionItemDao {
    @Query("SELECT * FROM action_items WHERE noteId = :noteId ORDER BY createdAt ASC")
    fun getActionItemsForNote(noteId: String): Flow<List<ActionItemEntity>>

    @Query("SELECT * FROM action_items WHERE userId = :userId ORDER BY isCompleted ASC, createdAt DESC")
    fun getAllActionItemsForUser(userId: String): Flow<List<ActionItemEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOrUpdate(item: ActionItemEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(items: List<ActionItemEntity>)

    @Update
    suspend fun update(item: ActionItemEntity)

    @Query("DELETE FROM action_items WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM action_items WHERE noteId = :noteId")
    suspend fun deleteForNote(noteId: String)
}
