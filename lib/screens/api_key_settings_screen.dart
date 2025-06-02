import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ApiKeySettingsScreen extends StatefulWidget {
  const ApiKeySettingsScreen({Key? key}) : super(key: key);

  // Clé pour sauvegarder la VALEUR de la clé API sélectionnée (utilisée par youtube_downloader.dart)
  static const String apiKeyPrefKey = 'rapidApiKey'; 
  // Nouvelle clé pour sauvegarder le NOM de la clé API sélectionnée (pour l'UI)
  static const String selectedApiKeyNamePrefKey = 'selectedApiKeyName';

  @override
  State<ApiKeySettingsScreen> createState() => _ApiKeySettingsScreenState();
}

class _ApiKeySettingsScreenState extends State<ApiKeySettingsScreen> {
  // Variables d'état
  bool _isFetchingKeys = true; // Indique le chargement initial des clés
  Map<String, String> _availableApiKeys = {}; // Stocke les clés récupérées {Nom: Valeur}
  String? _selectedApiKeyName; // Stocke le NOM de la clé sélectionnée
  String? _loadingError; // Pour afficher les erreurs de chargement

  @override
  void initState() {
    super.initState();
    _loadAvailableKeysAndSelection(); // Charge les clés et la sélection au démarrage
  }

  // Charge les clés depuis Firebase et la sélection précédente depuis SharedPreferences
  Future<void> _loadAvailableKeysAndSelection() async {
    setState(() {
      _isFetchingKeys = true;
      _loadingError = null; // Réinitialise l'erreur
      _availableApiKeys = {}; // Réinitialise les clés
      _selectedApiKeyName = null; // Réinitialise la sélection
    });

    try {
      // 1. Récupérer les clés depuis Firebase
      final ref = FirebaseDatabase.instance.ref('apiKeys');
      final snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null && snapshot.value is Map) {
        // Conversion prudente en Map<String, String>
        final Map<dynamic, dynamic> rawMap = snapshot.value as Map<dynamic, dynamic>;
        _availableApiKeys = rawMap.map((key, value) => 
            MapEntry(key.toString(), value.toString()));
      } else {
        // Aucune clé trouvée dans Firebase
        throw Exception('Aucune clé API trouvée dans Firebase (chemin: apiKeys). Veuillez en ajouter.');
      }

      // 2. Récupérer le nom de la dernière clé sélectionnée
      final prefs = await SharedPreferences.getInstance();
      final lastSelectedName = prefs.getString(ApiKeySettingsScreen.selectedApiKeyNamePrefKey);

      // 3. Vérifier si la clé précédemment sélectionnée existe toujours
      if (lastSelectedName != null && _availableApiKeys.containsKey(lastSelectedName)) {
        _selectedApiKeyName = lastSelectedName;
      } else {
         // Si la clé n'existe plus ou jamais sélectionnée, on ne présélectionne rien
         _selectedApiKeyName = null; 
         // Optionnel : Effacer l'ancienne clé invalide des prefs
         await prefs.remove(ApiKeySettingsScreen.apiKeyPrefKey);
         await prefs.remove(ApiKeySettingsScreen.selectedApiKeyNamePrefKey);
      }

    } catch (e) {
      print("Erreur chargement clés/sélection: $e");
      setState(() {
        _loadingError = "Erreur: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isFetchingKeys = false;
      });
    }
  }

  // Appelée lorsque l'utilisateur sélectionne une clé dans le Dropdown
  Future<void> _onApiKeySelected(String? selectedName) async {
    if (selectedName == null || !_availableApiKeys.containsKey(selectedName)) {
      // Ne devrait pas arriver si l'UI est correcte, mais sécurité
      return; 
    }

    final selectedKeyValue = _availableApiKeys[selectedName];

    if (selectedKeyValue == null || selectedKeyValue.trim().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: La valeur de la clé "$selectedName" est vide.')),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      // Sauvegarde la VALEUR de la clé pour le service downloader
      await prefs.setString(ApiKeySettingsScreen.apiKeyPrefKey, selectedKeyValue);
      // Sauvegarde le NOM de la clé pour l'UI
      await prefs.setString(ApiKeySettingsScreen.selectedApiKeyNamePrefKey, selectedName);

      setState(() {
        _selectedApiKeyName = selectedName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clé "$selectedName" sélectionnée et sauvegardée.')),
      );
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur sauvegarde sélection: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sélection Clé API', style: GoogleFonts.poppins()),
        backgroundColor: isDark ? Colors.grey[850] : Colors.grey[100],
        elevation: 1,
        actions: [
          // Bouton pour rafraîchir la liste des clés
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir la liste des clés',
            onPressed: _isFetchingKeys ? null : _loadAvailableKeysAndSelection,
          ),
        ],
      ),
      body: _buildBody(context, isDark),
    );
  }

  // Widget pour construire le corps du Scaffold
  Widget _buildBody(BuildContext context, bool isDark) {
    if (_isFetchingKeys) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadingError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_loadingError!, style: GoogleFonts.poppins(color: Colors.red)),
        ),
      );
    }

    if (_availableApiKeys.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Aucune clé API trouvée dans Firebase sous \'apiKeys\'. Veuillez en ajouter via la console Firebase.',
            style: GoogleFonts.poppins(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Affichage du Dropdown si tout va bien
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sélectionnez la clé API à utiliser :',
            style: GoogleFonts.poppins(fontSize: 16),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedApiKeyName, // Le NOM de la clé sélectionnée
            items: _availableApiKeys.keys.map((String keyName) {
              return DropdownMenuItem<String>(
                value: keyName,
                child: Text(keyName, style: GoogleFonts.poppins()),
              );
            }).toList(),
            onChanged: _onApiKeySelected, // Appelle la fonction de sauvegarde
            decoration: InputDecoration(
              labelText: 'Clé API disponible',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            // Validation (optionnelle, assure qu'une sélection est faite si nécessaire)
            validator: (value) {
              if (value == null) {
                return 'Veuillez sélectionner une clé API.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Note : La clé sélectionnée ici sera utilisée pour les téléchargements. Vous pouvez ajouter/modifier les clés disponibles directement dans la console Firebase sous le nœud \'apiKeys\'. Utilisez le bouton Rafraîchir (🔄) pour mettre à jour la liste.',
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
