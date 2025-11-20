import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:doa_roupa/banco/roupa_db.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class EditarPerfil extends StatefulWidget {
  const EditarPerfil({super.key});

  @override
  State<EditarPerfil> createState() => _EditarPerfilState();
}

class _EditarPerfilState extends State<EditarPerfil> {
  final RoupaDatabase _database = RoupaDatabase();

  final _nomeController = TextEditingController();
  final _idadeController = TextEditingController();
  final _profileUrlController = TextEditingController();

  final List<String> generosValidos = ['Masculino', 'Feminino', 'Outro'];
  String genero = 'Masculino';

  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  String normalizarGenero(String? g) {
    if (g == null) return generosValidos.first;
    final idx = generosValidos.indexWhere(
      (v) => v.toLowerCase().trim() == g.toLowerCase().trim(),
    );
    return idx == -1 ? generosValidos.first : generosValidos[idx];
  }

  Future<void> _carregarDadosUsuario() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      final usuario = await _database.getUsuario(currentUser.id);
      if (usuario != null) {
        setState(() {
          _nomeController.text = usuario.nome;
          genero = normalizarGenero(usuario.genero);
          _idadeController.text = usuario.idade?.toString() ?? '';
          _profileUrlController.text = usuario.profileUrl ?? '';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _imageBytes = bytes);
      } else {
        setState(() => _imageFile = File(pickedFile.path));
      }

      final uploadedUrl = await _uploadImage(pickedFile);
      if (uploadedUrl != null) {
        setState(() => _profileUrlController.text = uploadedUrl);
      }
    }
  }

  Future<String?> _uploadImage(XFile pickedFile) async {
    final fileName =
        'profile-images/${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      await Supabase.instance.client.storage
          .from('profile-images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/png'),
          );
    } else {
      await Supabase.instance.client.storage
          .from('profile-images')
          .upload(fileName, File(pickedFile.path));
    }

    return Supabase.instance.client.storage
        .from('profile-images')
        .getPublicUrl(fileName);
  }

  Future<void> _salvarAlteracoes() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      final usuario = await _database.getUsuario(currentUser.id);
      if (usuario != null) {
        final novoUsuario = usuario.copyWith(
          nome: _nomeController.text,
          genero: genero,
          idade: int.tryParse(_idadeController.text),
          profileUrl: _profileUrlController.text.isNotEmpty
              ? _profileUrlController.text
              : null,
        );

        await _database.atualizarUsuario(novoUsuario);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;

    if (_profileUrlController.text.isNotEmpty) {
      imageProvider = NetworkImage(_profileUrlController.text);
    } else if (kIsWeb && _imageBytes != null) {
      imageProvider = MemoryImage(_imageBytes!);
    } else if (!kIsWeb && _imageFile != null) {
      imageProvider = FileImage(_imageFile!);
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Editar Perfil', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? const Icon(Icons.camera_alt,
                          size: 40, color: Colors.white)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nomeController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: genero,
              items: generosValidos
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => genero = v);
              },
              decoration: const InputDecoration(
                labelText: 'Gênero',
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
              ),
              dropdownColor: Colors.white,
              iconEnabledColor: Colors.black,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _idadeController,
              decoration: const InputDecoration(labelText: 'Idade'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _salvarAlteracoes,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child:
                  const Text('Salvar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
