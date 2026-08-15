/// Backend endpoint used by the RAG feature.
///
/// Pick one mode:
///  - Cloud (Render): `https://<your-service>.onrender.com`
///  - Android emulator + laptop: `http://10.0.2.2:8000`
///  - Physical phone + laptop: `http://<PC-LAN-IP>:8000`
///
/// Switch by editing [kUseCloudBackend] — the value is only a first-run
/// default; the RAG setup screen lets the user override it at runtime.
const bool kUseCloudBackend = true;

const String kBackendBaseUrl = kUseCloudBackend
    ? 'https://reader-app-mi59.onrender.com'
    : 'http://10.0.2.2:8000';
