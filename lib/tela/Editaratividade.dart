import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:doa_roupa/modelo/atividade.dart';
import 'package:doa_roupa/banco/roupa_db.dart';

class EditarAtividade extends StatefulWidget {
  final String? atividadeId;
  const EditarAtividade({super.key, required this.atividadeId});

  @override
  State<EditarAtividade> createState() => _EditarAtividadeState();
}

class _EditarAtividadeState extends State<EditarAtividade> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tipoController = TextEditingController();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _dataInicioController = TextEditingController();
  final TextEditingController _dataFimController = TextEditingController();
  List<Map<String, dynamic>> _itens = [];
  final RoupaDatabase _database = RoupaDatabase();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarAtividade();
  }

  /// Carrega os dados da atividade com base no ID.
  Future<void> _carregarAtividade() async {
    if (widget.atividadeId != null) {
      try {
        final todas = await _database.getTodasAtividades();
        final atividade = todas.firstWhere((a) => a.id == widget.atividadeId);
        setState(() {
          _tipoController.text = atividade.tipo;
          _tituloController.text = atividade.titulo;
          _descricaoController.text = atividade.descricao;
          _dataInicioController.text =
              DateFormat('dd/MM/yyyy').format(atividade.dataInicio);
          _dataFimController.text =
              DateFormat('dd/MM/yyyy').format(atividade.dataFim);
          _itens = List<Map<String, dynamic>>.from(atividade.itens);
          isLoading = false;
        });
      } catch (e) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao carregar atividade: $e')));
      }
    }
  }

  /// Permite editar um item da lista.
  Future<void> _editarItem(int index) async {
    final currentItem = _itens[index];
    final tipoController =
        TextEditingController(text: currentItem['tipo_roupa']);
    final generoController = TextEditingController(text: currentItem['genero']);
    final tamanhoController =
        TextEditingController(text: currentItem['tamanho']);
    final quantidadeController =
        TextEditingController(text: currentItem['quantidade'].toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tipoController,
              decoration: const InputDecoration(labelText: 'Tipo de Roupa'),
            ),
            TextField(
              controller: generoController,
              decoration: const InputDecoration(labelText: 'Gênero'),
            ),
            TextField(
              controller: tamanhoController,
              decoration: const InputDecoration(labelText: 'Tamanho'),
            ),
            TextField(
              controller: quantidadeController,
              decoration: const InputDecoration(labelText: 'Quantidade'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar')),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        int q = int.tryParse(quantidadeController.text) ?? 0;
        _itens[index] = {
          'tipo_roupa': tipoController.text,
          'genero': generoController.text,
          'tamanho': tamanhoController.text,
          'quantidade': q,
          'quantidade_total': q,
        };
      });
    }
  }

  /// Remove um item da lista.
  void _removerItem(int index) {
    setState(() {
      _itens.removeAt(index);
    });
  }

  /// Converte uma string no formato 'dd/MM/yyyy' para DateTime.
  DateTime? _parseData(String data) {
    try {
      return DateFormat('dd/MM/yyyy').parse(data);
    } catch (e) {
      return null;
    }
  }

  /// Salva as alterações na atividade; se [novoStatus] for informado, atualiza o status.
  Future<void> _salvarAlteracoes({String? novoStatus}) async {
    if (_formKey.currentState!.validate()) {
      final dataInicio = _parseData(_dataInicioController.text);
      final dataFim = _parseData(_dataFimController.text);
      if (dataInicio == null ||
          dataFim == null ||
          dataInicio.isAfter(dataFim) ||
          dataFim.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Datas inválidas.')));
        return;
      }
      final atividadeAtualizada = Atividade(
        id: widget.atividadeId,
        tipo: _tipoController.text,
        titulo: _tituloController.text,
        descricao: _descricaoController.text,
        itens: _itens,
        dataInicio: dataInicio,
        dataFim: dataFim,
        status: novoStatus ?? 'em andamento',
      );
      try {
        await _database.atualizarAtividade(atividadeAtualizada);
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar atividade: $e')));
      }
    }
  }

  /// Finaliza a atividade apenas zerando as quantidades dos itens.
  Future<void> _finalizarAtividade() async {
    for (var item in _itens) {
      item['quantidade'] = 0;
    }
    await _salvarAlteracoes(novoStatus: 'concluída');
  }

  /// Atualiza o estoque para um item específico
  Future<bool> _atualizarEstoqueItem({
    required String tipo,
    required String genero,
    required String tamanho,
    required int quantidade,
  }) async {
    final response = await _database.client
        .from('estoque')
        .select('quantidade')
        .eq('tipo_roupa', tipo)
        .eq('genero', genero)
        .eq('tamanho', tamanho)
        .maybeSingle();
    if (response != null && response['quantidade'] != null) {
      int estoqueAtual = response['quantidade'] as int;
      if (estoqueAtual >= quantidade) {
        await _database.client
            .from('estoque')
            .update({'quantidade': estoqueAtual - quantidade})
            .eq('tipo_roupa', tipo)
            .eq('genero', genero)
            .eq('tamanho', tamanho);
        return true;
      } else {
        return false;
      }
    } else {
      return false;
    }
  }

  /// Tenta descontar o estoque para cada item; se todos forem descontados, define o status para "concluída".
  Future<void> _concluirDoacoes() async {
    bool todosDescontados = true;
    for (var item in _itens) {
      final bool descontou = await _atualizarEstoqueItem(
        tipo: item['tipo_roupa'],
        genero: item['genero'],
        tamanho: item['tamanho'],
        quantidade: item['quantidade'],
      );
      if (descontou) {
        item['quantidade'] = 0;
      } else {
        todosDescontados = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Estoque insuficiente para ${item['tipo_roupa']}')),
        );
      }
    }
    if (todosDescontados) {
      await _salvarAlteracoes(novoStatus: 'concluída');
    } else {
      await _salvarAlteracoes();
    }
  }

  /// Adiciona um novo item à lista.
  Future<void> _adicionarItem() async {
    final tipo = await _mostrarDialogoItem('Tipo de Roupa');
    final genero = await _mostrarDialogoItem('Gênero');
    final tamanho = await _mostrarDialogoItem('Tamanho');
    final quantidade = await _mostrarDialogoItem('Quantidade');
    if (tipo != null &&
        genero != null &&
        tamanho != null &&
        quantidade != null &&
        quantidade.isNotEmpty) {
      setState(() {
        int q = int.tryParse(quantidade) ?? 0;
        _itens.add({
          'tipo_roupa': tipo,
          'genero': genero,
          'tamanho': tamanho,
          'quantidade': q,
          'quantidade_total': q,
        });
      });
    }
  }

  Future<String?> _mostrarDialogoItem(String titulo) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: controller,
          keyboardType: titulo == 'Quantidade'
              ? TextInputType.number
              : TextInputType.text,
          inputFormatters: titulo == 'Quantidade'
              ? [FilteringTextInputFormatter.digitsOnly]
              : [],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Editar Atividade'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _campo(_tipoController, 'Tipo'),
              const SizedBox(height: 16),
              _campo(_tituloController, 'Título'),
              const SizedBox(height: 16),
              _campo(_descricaoController, 'Descrição'),
              const SizedBox(height: 16),
              _campo(_dataInicioController, 'Data Início (dd/MM/yyyy)'),
              const SizedBox(height: 16),
              _campo(_dataFimController, 'Data Fim (dd/MM/yyyy)'),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _itens.length,
                  itemBuilder: (context, index) {
                    final item = _itens[index];
                    return Card(
                      color: Colors.white,
                      elevation: 1,
                      child: ListTile(
                        title: Text(
                          '${item['quantidade']} ${item['tipo_roupa']}',
                          style: const TextStyle(color: Colors.black),
                        ),
                        subtitle: Text(
                          'Tamanho: ${item['tamanho']}, Gênero: ${item['genero']}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editarItem(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removerItem(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _botao('Adicionar Item', _adicionarItem),
                  _botao('Salvar Alterações', _salvarAlteracoes),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _botaoCor(
                      'Finalizar Atividade', _finalizarAtividade, Colors.red),
                  _botaoCor('Concluir Doações', _concluirDoacoes, Colors.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[200],
        labelStyle: const TextStyle(color: Colors.black),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
      style: const TextStyle(color: Colors.black),
    );
  }

  Widget _botao(String texto, Function acao) {
    return ElevatedButton(
      onPressed: () => acao(),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _botaoCor(String texto, Function acao, Color cor) {
    return ElevatedButton(
      onPressed: () => acao(),
      style: ElevatedButton.styleFrom(
        backgroundColor: cor,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}
