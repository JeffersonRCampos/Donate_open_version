import 'package:flutter/material.dart';
import 'package:doa_roupa/modelo/atividade.dart';
import 'package:doa_roupa/banco/roupa_db.dart';

class VerAtividadesConcluidas extends StatefulWidget {
  const VerAtividadesConcluidas({super.key});
  @override
  State<VerAtividadesConcluidas> createState() =>
      _VerAtividadesConcluidasState();
}

class _VerAtividadesConcluidasState extends State<VerAtividadesConcluidas> {
  final RoupaDatabase _database = RoupaDatabase();
  List<Atividade> atividades = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final todas = await _database.getTodasAtividades();
      final filtradas = todas.where((a) => a.status == 'concluída').toList();
      filtradas.sort((a, b) => a.dataInicio.compareTo(b.dataInicio));

      setState(() {
        atividades = filtradas;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar atividades: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Atividades Encerradas',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : atividades.isEmpty
              ? const Center(child: Text('Nenhuma atividade encerrada.'))
              : ListView.builder(
                  itemCount: atividades.length,
                  itemBuilder: (context, index) {
                    final atividade = atividades[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: ListTile(
                        title: Text(atividade.titulo),
                        subtitle: Text(atividade.descricao),
                      ),
                    );
                  },
                ),
    );
  }
}
