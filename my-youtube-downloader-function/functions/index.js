const functions = require("firebase-functions");
const axios = require("axios");

// IMPORTANT : Récupérer la clé API depuis la configuration d'environnement Firebase
// Nous verrons comment la configurer à l'étape suivante.
const RAPIDAPI_KEY = functions.config().rapidapi ? functions.config().rapidapi.key : undefined;
const RAPIDAPI_HOST = "youtube-mp3-audio-video-downloader.p.rapidapi.com";
const BASE_URL = "https://youtube-mp3-audio-video-downloader.p.rapidapi.com/download-mp3/";

/**
 * Extrait l'ID vidéo d'une URL YouTube ou retourne l'entrée si c'est déjà un ID.
 * @param {string} urlOrId L'URL complète ou l'ID de la vidéo YouTube.
 * @return {string|null} L'ID de la vidéo ou null si invalide.
 */
function extractVideoId(urlOrId) {
  if (!urlOrId) return null;
  // Regex pour extraire l'ID de différentes formes d'URL YouTube
  const patterns = [
    /(?:https?:\/\/)?(?:www\.)?youtube\.com\/(?:watch\?v=|embed\/|v\/|)([\w-]{11})(?:\S+)?$/,
    /(?:https?:\/\/)?(?:www\.)?youtu\.be\/([\w-]{11})(?:\S+)?$/,
  ];

  for (const pattern of patterns) {
    const match = urlOrId.match(pattern);
    if (match && match[1]) {
      return match[1];
    }
  }

  // Vérifie si l'entrée est déjà un ID valide
  if (urlOrId.length === 11 && /^[\w-]{11}$/.test(urlOrId)) {
    return urlOrId;
  }

  return null;
}

// Définition de la fonction Cloud HTTP
exports.downloadMp3 = functions.https.onRequest(async (req, res) => {
  // Vérifier si la clé API est configurée
  if (!RAPIDAPI_KEY) {
    console.error("Erreur: Clé RapidAPI non configurée dans l'environnement Firebase.");
    res.status(500).send("Erreur serveur: Configuration manquante.");
    return;
  }

  // Récupérer l'URL ou l'ID depuis les paramètres de la requête (ex: ?url=VIDEO_ID)
  const videoUrlOrId = req.query.url;
  const quality = req.query.quality || "low"; // Qualité par défaut 'low'

  if (!videoUrlOrId) {
    res.status(400).send("Paramètre 'url' manquant (ID ou URL YouTube).");
    return;
  }

  const videoId = extractVideoId(videoUrlOrId);

  if (!videoId) {
    res.status(400).send("URL ou ID YouTube invalide fourni.");
    return;
  }

  const apiUrl = `${BASE_URL}${videoId}?quality=${quality}`;
  const options = {
    method: "GET",
    url: apiUrl,
    headers: {
      "x-rapidapi-key": RAPIDAPI_KEY,
      "x-rapidapi-host": RAPIDAPI_HOST,
    },
    responseType: "arraybuffer", // Important pour recevoir les données binaires (MP3)
  };

  try {
    console.log(`Tentative de téléchargement MP3 pour l'ID: ${videoId}`);
    const response = await axios.request(options);

    // Vérifier le type de contenu (peut varier légèrement selon l'API)
    const contentType = response.headers["content-type"];
    console.log(`Réponse reçue avec statut ${response.status} et type ${contentType}`);

    if (response.status === 200 && contentType && (contentType.includes("audio/mpeg") || contentType.includes("application/octet-stream"))) {
      // Envoyer les données MP3 brutes
      res.set("Content-Type", "audio/mpeg");
      res.set("Content-Disposition", `attachment; filename="${videoId}.mp3"`); // Suggère un nom de fichier
      res.status(200).send(Buffer.from(response.data, "binary"));
    } else {
      // L'API a peut-être renvoyé une erreur ou un type de contenu inattendu
      console.error("Réponse inattendue de l'API RapidAPI:", response.status, contentType, response.data.toString());
      res.status(502).send(`Erreur lors de la communication avec l'API externe. Statut: ${response.status}`);
    }
  } catch (error) {
    console.error("Erreur lors de l'appel à RapidAPI:", error.response ? { status: error.response.status, data: error.response.data.toString() } : error.message);
    if (error.response) {
      // Transférer l'erreur de l'API externe si possible
      res.status(error.response.status || 500).send(`Erreur de l'API externe: ${error.response.data.toString()}`);
    } else {
      res.status(500).send("Erreur interne du serveur lors de l'appel API.");
    }
  }
});
