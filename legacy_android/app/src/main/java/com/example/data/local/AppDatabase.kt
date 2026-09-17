package com.example.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.example.data.model.ActionItemEntity
import com.example.data.model.EmailActivityRecord
import com.example.data.model.FolderEntity
import com.example.data.model.NoteEntity

@Database(
    entities = [
        NoteEntity::class,
        ActionItemEntity::class,
        FolderEntity::class,
        EmailActivityRecord::class
    ],
    version = 1,
    exportSchema = false
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun noteDao(): NoteDao
    abstract fun actionItemDao(): ActionItemDao
    abstract fun folderDao(): FolderDao
    abstract fun emailActivityDao(): EmailActivityDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getInstance(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "noteflow_database.db"
                ).fallbackToDestructiveMigration().build()
                INSTANCE = instance
                instance
            }
        }
    }
}
