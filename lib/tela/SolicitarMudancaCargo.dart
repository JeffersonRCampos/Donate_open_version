import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doa_roupa/modelo/usuario.dart';

class AprovarMudancaCargo extends StatefulWidget {
  const AprovarMudancaCargo({super.key});

  @override
  State<AprovarMudancaCargo> createState() => _AprovarMudancaCargoState();
}

class _AprovarMudancaCargoState extends State<AprovarMudancaCargo> {
  final SupabaseClient client = Supabase.instance.client;

  List<Usuario> usuarios = [];
  bool isLoading = true;

  String get adminAtualId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  Future<void> _carregarUsuarios() async {
    try {
      final response = await client.from('usuarios').select();

      final lista = (response as List)
          .map((e) => Usuario.fromMap(e as Map<String, dynamic>))
          .toList();

      setState(() {
        usuarios = lista;
        isLoading = false;
      });
    } catch (error) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar usuários: $error')),
      );
    }
  }

  Future<void> _alterarCargo(Usuario usuario, String novoCargo) async {
    try {
      await client.from('usuarios').update({
        'papel': novoCargo,
      }).eq('id', usuario.id);

      await _carregarUsuarios();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao alterar cargo: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gerenciar Cargos',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : usuarios.isEmpty
              ? const Center(child: Text('Nenhum usuário encontrado.'))
              : ListView.builder(
                  itemCount: usuarios.length,
                  itemBuilder: (context, index) {
                    final user = usuarios[index];

                    final bool isSelf = user.id == adminAtualId;
                    final bool isAdmin = user.papel == 'admin';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 10),
                      child: ListTile(
                        title: Text(user.nome),
                        subtitle: Text('Cargo atual: ${user.papel}'),
                        trailing: isSelf
                            ? const Text('Você',
                                style: TextStyle(fontWeight: FontWeight.bold))
                            : PopupMenuButton<String>(
                                onSelected: (value) =>
                                    _alterarCargo(user, value),
                                itemBuilder: (context) => [
                                  if (!isAdmin)
                                    const PopupMenuItem(
                                      value: 'admin',
                                      child: Text('Promover para admin'),
                                    ),
                                  if (isAdmin)
                                    const PopupMenuItem(
                                      value: 'doador',
                                      child: Text('Rebaixar para doador'),
                                    ),
                                ],
                                child: const Icon(Icons.more_vert),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
