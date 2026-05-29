enum BackupSettings {
    enum Config {
        static let folderBookmarkKey = "iAPS.backupFolderBookmark"
        static let folderDisplayPathKey = "iAPS.backupFolderDisplayPath"
        static let lastBackupAtKey = "iAPS.lastBackupAt"
        static let rollingBackupCount = 7
    }
}

protocol BackupSettingsProvider: Provider {}
