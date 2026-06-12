import Foundation

/// Eigenes, leichtgewichtiges Lokalisierungssystem für das Tidepool-Modul.
///
/// Gleiches Muster wie `AIHubL10n`: Bewusst NICHT über Localizable.strings/Crowdin,
/// weil das selbst gebaute Tidepool-Modul nicht in den offiziellen iAPS-Source
/// aufgenommen wird und dort nie übersetzt würde. „Tidepool" selbst ist ein
/// Eigenname und bleibt unübersetzt.
enum TidepoolL10n {
    static var languageCode: String {
        let preferred = Bundle.main.preferredLocalizations.first ?? "en"
        if tables[preferred] != nil { return preferred }
        let base = String(preferred.prefix(2))
        return tables[base] != nil ? base : "en"
    }

    static func t(_ key: String) -> String {
        tables[languageCode]?[key] ?? tables["en"]?[key] ?? key
    }

    // MARK: - Tabellen

    static let tables: [String: [String: String]] = [
        "en": en,
        "de": de,
        "fr": fr,
        "it": it,
        "es": es,
        "nl": nl,
        "pl": pl,
        "sv": sv,
        "da": da,
        "nb": nb,
        "fi": fi,
        "pt": pt,
        "pt-BR": ptBR,
        "ru": ru,
        "tr": tr,
        "uk": uk,
        "sk": sk,
        "hu": hu,
        "ar": ar,
        "he": he,
        "el": el,
        "ca": ca,
        "vi": vi,
        "zh-Hans": zhHans
    ]

    // MARK: English (Basis/Fallback)

    private static let en: [String: String] = [
        "section.header": "Tidepool Integration",
        "connected": "Connected to Tidepool",
        "connect": "Connect to Tidepool",
        "unavailable": "Tidepool service unavailable",
        "footer": "You can connect iAPS to Tidepool to upload and manage your diabetes data. Log in with your Tidepool credentials, or sign up on the login page.\n\nWhen connected, iAPS uploads glucose, carb entries, insulin (bolus and basal), and therapy settings (basal schedules, carb ratios, insulin sensitivities, glucose targets)."
    ]

    // MARK: Deutsch

    private static let de: [String: String] = [
        "section.header": "Tidepool-Integration",
        "connected": "Mit Tidepool verbunden",
        "connect": "Mit Tidepool verbinden",
        "unavailable": "Tidepool-Dienst nicht verfügbar",
        "footer": "Du kannst iAPS mit Tidepool verbinden, um deine Diabetesdaten hochzuladen und zu verwalten. Melde dich mit deinen Tidepool-Zugangsdaten an oder registriere dich auf der Login-Seite.\n\nWenn verbunden, lädt iAPS Glukosewerte, Kohlenhydrat-Einträge, Insulin (Bolus und Basal) und Therapieeinstellungen hoch (Basalprofile, KH-Verhältnisse, Insulin-Sensitivitäten, Glukoseziele)."
    ]

    // MARK: Français

    private static let fr: [String: String] = [
        "section.header": "Intégration Tidepool",
        "connected": "Connecté à Tidepool",
        "connect": "Se connecter à Tidepool",
        "unavailable": "Service Tidepool indisponible",
        "footer": "Vous pouvez connecter iAPS à Tidepool pour téléverser et gérer vos données de diabète. Connectez-vous avec vos identifiants Tidepool ou inscrivez-vous sur la page de connexion.\n\nUne fois connecté, iAPS téléverse la glycémie, les entrées de glucides, l'insuline (bolus et basal) et les réglages de thérapie (profils basaux, ratios de glucides, sensibilités à l'insuline, cibles glycémiques)."
    ]

    // MARK: Italiano

    private static let it: [String: String] = [
        "section.header": "Integrazione Tidepool",
        "connected": "Connesso a Tidepool",
        "connect": "Connetti a Tidepool",
        "unavailable": "Servizio Tidepool non disponibile",
        "footer": "Puoi collegare iAPS a Tidepool per caricare e gestire i tuoi dati sul diabete. Accedi con le tue credenziali Tidepool oppure registrati nella pagina di accesso.\n\nUna volta connesso, iAPS carica glicemia, carboidrati, insulina (bolo e basale) e impostazioni terapeutiche (profili basali, rapporti carboidrati, sensibilità insulinica, obiettivi glicemici)."
    ]

    // MARK: Español

    private static let es: [String: String] = [
        "section.header": "Integración con Tidepool",
        "connected": "Conectado a Tidepool",
        "connect": "Conectar con Tidepool",
        "unavailable": "Servicio de Tidepool no disponible",
        "footer": "Puedes conectar iAPS a Tidepool para subir y gestionar tus datos de diabetes. Inicia sesión con tus credenciales de Tidepool o regístrate en la página de acceso.\n\nUna vez conectado, iAPS sube glucosa, entradas de carbohidratos, insulina (bolo y basal) y ajustes de terapia (perfiles basales, ratios de carbohidratos, sensibilidades a la insulina, objetivos de glucosa)."
    ]

    // MARK: Nederlands

    private static let nl: [String: String] = [
        "section.header": "Tidepool-integratie",
        "connected": "Verbonden met Tidepool",
        "connect": "Verbinden met Tidepool",
        "unavailable": "Tidepool-service niet beschikbaar",
        "footer": "Je kunt iAPS met Tidepool verbinden om je diabetesgegevens te uploaden en te beheren. Log in met je Tidepool-gegevens of registreer je op de inlogpagina.\n\nEenmaal verbonden uploadt iAPS glucose, koolhydraatinvoer, insuline (bolus en basaal) en therapie-instellingen (basaalprofielen, koolhydraatratio's, insulinegevoeligheden, glucosedoelen)."
    ]

    // MARK: Polski

    private static let pl: [String: String] = [
        "section.header": "Integracja z Tidepool",
        "connected": "Połączono z Tidepool",
        "connect": "Połącz z Tidepool",
        "unavailable": "Usługa Tidepool niedostępna",
        "footer": "Możesz połączyć iAPS z Tidepool, aby przesyłać i zarządzać danymi o cukrzycy. Zaloguj się danymi Tidepool lub zarejestruj się na stronie logowania.\n\nPo połączeniu iAPS przesyła glikemię, wpisy węglowodanów, insulinę (bolus i baza) oraz ustawienia terapii (profile bazowe, przeliczniki węglowodanów, wrażliwość na insulinę, cele glikemii)."
    ]

    // MARK: Svenska

    private static let sv: [String: String] = [
        "section.header": "Tidepool-integration",
        "connected": "Ansluten till Tidepool",
        "connect": "Anslut till Tidepool",
        "unavailable": "Tidepool-tjänsten är inte tillgänglig",
        "footer": "Du kan ansluta iAPS till Tidepool för att ladda upp och hantera dina diabetesdata. Logga in med dina Tidepool-uppgifter eller registrera dig på inloggningssidan.\n\nNär anslutningen är klar laddar iAPS upp glukos, kolhydratposter, insulin (bolus och basal) och behandlingsinställningar (basalprofiler, kolhydratkvoter, insulinkänsligheter, glukosmål)."
    ]

    // MARK: Dansk

    private static let da: [String: String] = [
        "section.header": "Tidepool-integration",
        "connected": "Forbundet til Tidepool",
        "connect": "Forbind til Tidepool",
        "unavailable": "Tidepool-tjenesten er ikke tilgængelig",
        "footer": "Du kan forbinde iAPS til Tidepool for at uploade og administrere dine diabetesdata. Log ind med dine Tidepool-oplysninger, eller tilmeld dig på login-siden.\n\nNår forbindelsen er oprettet, uploader iAPS glukose, kulhydratindtastninger, insulin (bolus og basal) og behandlingsindstillinger (basalprofiler, kulhydratforhold, insulinfølsomheder, glukosemål)."
    ]

    // MARK: Norsk (bokmål)

    private static let nb: [String: String] = [
        "section.header": "Tidepool-integrasjon",
        "connected": "Koblet til Tidepool",
        "connect": "Koble til Tidepool",
        "unavailable": "Tidepool-tjenesten er utilgjengelig",
        "footer": "Du kan koble iAPS til Tidepool for å laste opp og administrere diabetesdataene dine. Logg inn med Tidepool-kontoen din, eller registrer deg på innloggingssiden.\n\nNår tilkoblingen er aktiv, laster iAPS opp glukose, karbohydratoppføringer, insulin (bolus og basal) og behandlingsinnstillinger (basalprofiler, karbohydratforhold, insulinfølsomhet, glukosemål)."
    ]

    // MARK: Suomi

    private static let fi: [String: String] = [
        "section.header": "Tidepool-integraatio",
        "connected": "Yhdistetty Tidepooliin",
        "connect": "Yhdistä Tidepooliin",
        "unavailable": "Tidepool-palvelu ei ole käytettävissä",
        "footer": "Voit yhdistää iAPSin Tidepooliin diabetestietojesi lataamista ja hallintaa varten. Kirjaudu Tidepool-tunnuksillasi tai rekisteröidy kirjautumissivulla.\n\nKun yhteys on muodostettu, iAPS lataa glukoosin, hiilihydraattimerkinnät, insuliinin (bolus ja basaali) sekä hoitoasetukset (basaaliprofiilit, hiilihydraattisuhteet, insuliiniherkkyydet, glukoositavoitteet)."
    ]

    // MARK: Português (Portugal)

    private static let pt: [String: String] = [
        "section.header": "Integração Tidepool",
        "connected": "Ligado ao Tidepool",
        "connect": "Ligar ao Tidepool",
        "unavailable": "Serviço Tidepool indisponível",
        "footer": "Pode ligar o iAPS ao Tidepool para carregar e gerir os seus dados de diabetes. Inicie sessão com as suas credenciais Tidepool ou registe-se na página de início de sessão.\n\nQuando ligado, o iAPS carrega glicose, entradas de hidratos de carbono, insulina (bólus e basal) e definições de terapia (perfis basais, rácios de hidratos de carbono, sensibilidades à insulina, alvos de glicose)."
    ]

    // MARK: Português (Brasil)

    private static let ptBR: [String: String] = [
        "section.header": "Integração Tidepool",
        "connected": "Conectado ao Tidepool",
        "connect": "Conectar ao Tidepool",
        "unavailable": "Serviço Tidepool indisponível",
        "footer": "Você pode conectar o iAPS ao Tidepool para enviar e gerenciar seus dados de diabetes. Faça login com suas credenciais Tidepool ou cadastre-se na página de login.\n\nQuando conectado, o iAPS envia glicose, registros de carboidratos, insulina (bolus e basal) e configurações de terapia (perfis basais, razões de carboidratos, sensibilidades à insulina, alvos de glicose)."
    ]

    // MARK: Русский

    private static let ru: [String: String] = [
        "section.header": "Интеграция с Tidepool",
        "connected": "Подключено к Tidepool",
        "connect": "Подключиться к Tidepool",
        "unavailable": "Сервис Tidepool недоступен",
        "footer": "Вы можете подключить iAPS к Tidepool, чтобы загружать свои данные о диабете и управлять ими. Войдите с учётными данными Tidepool или зарегистрируйтесь на странице входа.\n\nПосле подключения iAPS загружает глюкозу, записи углеводов, инсулин (болюс и базал) и настройки терапии (базальные профили, углеводные коэффициенты, чувствительность к инсулину, целевые уровни глюкозы)."
    ]

    // MARK: Türkçe

    private static let tr: [String: String] = [
        "section.header": "Tidepool Entegrasyonu",
        "connected": "Tidepool'a bağlı",
        "connect": "Tidepool'a bağlan",
        "unavailable": "Tidepool hizmeti kullanılamıyor",
        "footer": "Diyabet verilerinizi yüklemek ve yönetmek için iAPS'i Tidepool'a bağlayabilirsiniz. Tidepool kimlik bilgilerinizle giriş yapın veya giriş sayfasından kaydolun.\n\nBağlandığında iAPS; glukoz, karbonhidrat girişleri, insülin (bolus ve bazal) ve tedavi ayarlarını (bazal programları, karbonhidrat oranları, insülin duyarlılıkları, glukoz hedefleri) yükler."
    ]

    // MARK: Українська

    private static let uk: [String: String] = [
        "section.header": "Інтеграція з Tidepool",
        "connected": "Підключено до Tidepool",
        "connect": "Підключитися до Tidepool",
        "unavailable": "Сервіс Tidepool недоступний",
        "footer": "Ви можете підключити iAPS до Tidepool, щоб завантажувати свої дані про діабет і керувати ними. Увійдіть з обліковими даними Tidepool або зареєструйтеся на сторінці входу.\n\nПісля підключення iAPS завантажує глюкозу, записи вуглеводів, інсулін (болюс і базал) та налаштування терапії (базальні профілі, вуглеводні коефіцієнти, чутливість до інсуліну, цільові рівні глюкози)."
    ]

    // MARK: Slovenčina

    private static let sk: [String: String] = [
        "section.header": "Integrácia Tidepool",
        "connected": "Pripojené k Tidepool",
        "connect": "Pripojiť k Tidepool",
        "unavailable": "Služba Tidepool nie je dostupná",
        "footer": "iAPS môžete pripojiť k Tidepool a nahrávať a spravovať svoje údaje o cukrovke. Prihláste sa svojimi údajmi Tidepool alebo sa zaregistrujte na prihlasovacej stránke.\n\nPo pripojení iAPS nahráva glukózu, záznamy sacharidov, inzulín (bolus a bazál) a nastavenia terapie (bazálne profily, sacharidové pomery, citlivosť na inzulín, glykemické ciele)."
    ]

    // MARK: Magyar

    private static let hu: [String: String] = [
        "section.header": "Tidepool-integráció",
        "connected": "Csatlakoztatva a Tidepoolhoz",
        "connect": "Csatlakozás a Tidepoolhoz",
        "unavailable": "A Tidepool szolgáltatás nem érhető el",
        "footer": "Az iAPS-t összekapcsolhatod a Tidepoollal, hogy feltöltsd és kezeld a cukorbetegség-adataidat. Jelentkezz be a Tidepool-fiókoddal, vagy regisztrálj a bejelentkezési oldalon.\n\nCsatlakozás után az iAPS feltölti a glükózt, a szénhidrát-bejegyzéseket, az inzulint (bólus és bazál) és a terápiás beállításokat (bazálprofilok, szénhidrát-arányok, inzulinérzékenységek, glükózcélok)."
    ]

    // MARK: العربية

    private static let ar: [String: String] = [
        "section.header": "تكامل Tidepool",
        "connected": "متصل بـ Tidepool",
        "connect": "الاتصال بـ Tidepool",
        "unavailable": "خدمة Tidepool غير متاحة",
        "footer": "يمكنك ربط iAPS بـ Tidepool لرفع بيانات السكري الخاصة بك وإدارتها. سجّل الدخول ببيانات اعتماد Tidepool أو أنشئ حسابًا في صفحة تسجيل الدخول.\n\nعند الاتصال، يرفع iAPS الجلوكوز وإدخالات الكربوهيدرات والأنسولين (البلعة والبازال) وإعدادات العلاج (جداول البازال ونسب الكربوهيدرات وحساسيات الأنسولين وأهداف الجلوكوز)."
    ]

    // MARK: עברית

    private static let he: [String: String] = [
        "section.header": "שילוב Tidepool",
        "connected": "מחובר ל-Tidepool",
        "connect": "התחבר ל-Tidepool",
        "unavailable": "שירות Tidepool אינו זמין",
        "footer": "ניתן לחבר את iAPS ל-Tidepool כדי להעלות ולנהל את נתוני הסוכרת שלך. התחבר עם פרטי ההתחברות של Tidepool או הירשם בדף ההתחברות.\n\nכשמחובר, iAPS מעלה גלוקוז, רישומי פחמימות, אינסולין (בולוס ובזאלי) והגדרות טיפול (פרופילי בזאלי, יחסי פחמימות, רגישויות לאינסולין, יעדי גלוקוז)."
    ]

    // MARK: Ελληνικά

    private static let el: [String: String] = [
        "section.header": "Ενσωμάτωση Tidepool",
        "connected": "Συνδεδεμένο με το Tidepool",
        "connect": "Σύνδεση με το Tidepool",
        "unavailable": "Η υπηρεσία Tidepool δεν είναι διαθέσιμη",
        "footer": "Μπορείτε να συνδέσετε το iAPS με το Tidepool για να ανεβάζετε και να διαχειρίζεστε τα δεδομένα του διαβήτη σας. Συνδεθείτε με τα διαπιστευτήρια Tidepool ή εγγραφείτε στη σελίδα σύνδεσης.\n\nΌταν συνδεθεί, το iAPS ανεβάζει γλυκόζη, καταχωρίσεις υδατανθράκων, ινσουλίνη (bolus και βασική) και ρυθμίσεις θεραπείας (βασικά προφίλ, αναλογίες υδατανθράκων, ευαισθησίες ινσουλίνης, στόχους γλυκόζης)."
    ]

    // MARK: Català

    private static let ca: [String: String] = [
        "section.header": "Integració amb Tidepool",
        "connected": "Connectat a Tidepool",
        "connect": "Connecta amb Tidepool",
        "unavailable": "Servei de Tidepool no disponible",
        "footer": "Pots connectar iAPS amb Tidepool per pujar i gestionar les teves dades de diabetis. Inicia sessió amb les credencials de Tidepool o registra't a la pàgina d'accés.\n\nUn cop connectat, iAPS puja glucosa, entrades de carbohidrats, insulina (bol i basal) i configuració de teràpia (perfils basals, ràtios de carbohidrats, sensibilitats a la insulina, objectius de glucosa)."
    ]

    // MARK: Tiếng Việt

    private static let vi: [String: String] = [
        "section.header": "Tích hợp Tidepool",
        "connected": "Đã kết nối với Tidepool",
        "connect": "Kết nối với Tidepool",
        "unavailable": "Dịch vụ Tidepool không khả dụng",
        "footer": "Bạn có thể kết nối iAPS với Tidepool để tải lên và quản lý dữ liệu tiểu đường của mình. Đăng nhập bằng tài khoản Tidepool hoặc đăng ký trên trang đăng nhập.\n\nKhi đã kết nối, iAPS tải lên đường huyết, các mục carbohydrate, insulin (bolus và liều nền) và cài đặt điều trị (hồ sơ liều nền, tỷ lệ carbohydrate, độ nhạy insulin, mục tiêu đường huyết)."
    ]

    // MARK: 简体中文

    private static let zhHans: [String: String] = [
        "section.header": "Tidepool 集成",
        "connected": "已连接 Tidepool",
        "connect": "连接 Tidepool",
        "unavailable": "Tidepool 服务不可用",
        "footer": "你可以将 iAPS 连接到 Tidepool，以上传和管理你的糖尿病数据。使用 Tidepool 账号登录，或在登录页面注册。\n\n连接后，iAPS 会上传血糖、碳水记录、胰岛素（大剂量和基础率）以及治疗设置（基础率方案、碳水系数、胰岛素敏感系数、血糖目标）。"
    ]
}
