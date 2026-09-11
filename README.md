⚙️ Pré-requisitos
Sistema Operacional: Windows 10 ou Windows 11.

PowerShell: PowerShell 5.1 ou superior (nativo do Windows).

Navegador: Qualquer navegador moderno (Google Chrome, Microsoft Edge, Firefox).

Cabo USB: Conexão do coletor Zebra MC3300x em modo "Transferência de arquivo" (MTP).

🛠️ Como Executar o Sistema
Iniciar a aplicação:

Dê um duplo clique no arquivo iniciar_central.bat.

O PowerShell iniciará o servidor local na porta 5454 e abrirá a aplicação automaticamente no navegador padrão (http://localhost:5454).

Criar Atalho na Área de Trabalho:

Com o sistema aberto, clique no botão 🖥️ Criar Atalho no canto superior direito.

Um atalho estilizado com icone.ico será criado na sua Área de Trabalho apontando para o inicializador.

📲 Fluxo de Homologação / Staging (Zebra MC3300x)
Carga de Arquivos:

Coloque os arquivos necessários (instaladores .apk, certificados, perfis) dentro da pasta arquivos_carga.

Conecte o MC3300x no computador via USB.

Desbloqueie o coletor e confirme se a opção USB está em "Transferência de arquivo".

No topo da Central, clique em 📥 Enviar Arquivos USB. Os arquivos serão transferidos automaticamente para a pasta Download do aparelho.

Configuração de Rede:

Busque pelo nome ou série do equipamento no campo de pesquisa.

Com a câmera/leitor do Zebra, escaneie os QR Codes exibidos na tela para configurar IP, Gateway, DNS e Wi-Fi de forma ágil e sem digitação manual.

💾 Estrutura do Arquivo coletores.json
Os dados são armazenados localmente e atualizados de forma atômica pelo servidor:

JSON
{
  "plantas": [
    {
      "id": "planta_1700000000000",
      "nome": "Matriz - Sorocaba",
      "gateway": "192.168.1.1",
      "dns1": "8.8.8.8",
      "dns2": "8.8.4.4",
      "senhaWifi": "MinhaSenhaWifi"
    }
  ],
  "coletores": [
    {
      "id": 1,
      "nome": "CHR0001 - Expedição",
      "serie": "12345678901234",
      "mac": "00:1A:2B:3C:4D:5E",
      "ip": "192.168.1.105",
      "plantaId": "planta_1700000000000"
    }
  ],
  "atalhos": [
    {
      "id": "atalho_1700000000001",
      "nome": "RECEBIMENTO-DOCA-01",
      "plantaId": "planta_1700000000000"
    }
  ]
}
🔒 Segurança e Resiliência Local
Sem dependências externas: O backend não requer Node.js, Python, IIS ou bancos relacionais; utiliza apenas recursos nativos do PowerShell (System.Net.HttpListener).

Validação de Entrada: Tratamento contra injeção e sanitização de quebras de linha em respostas HTTP.

Tratamento de Timeout MTP: Mecanismo de leitura com fallback seguro no front-end para evitar falso-positivo em transferências de pacotes grandes.
"""

with open("README.md", "w", encoding="utf-8") as f:
f.write(readme_content)

print("README.md gerado com sucesso!")


```text?code_stdout&code_event_index=1
README.md gerado com sucesso!

Your Markdown file is ready


README
 MD 
O arquivo README.md completo do projeto foi criado com todas as especificações do sistema. Abaixo está o conteúdo formatado para referência direta:

📡 Central de Coletores (Zebra MC3300x)
Sistema integrado e autônomo para gerenciamento, auditoria e homologação de configurações de rede (IP estático, Gateway, DNS, Wi-Fi), geração instantânea de QR Codes para leitura via leitor 2D/StageNow, e automação de carga de arquivos via USB (MTP).

🚀 Principais Funcionalidades
Gestão Desacoplada por Plantas / Unidades:

Cadastro e administração de múltiplas filiais/plantas.

Centralização dos parâmetros de infraestrutura de rede por unidade: Gateway, DNS 1, DNS 2 e Senha Wi-Fi.

Vinculação rápida: ao selecionar a planta no coletor, as definições de rede são herdadas instantaneamente.

Cadastro e Consulta de Coletores:

Cadastro de Nº de Série (validação de 14 dígitos), Endereço MAC, Nome do Dispositivo, IP Fixo e Planta.

Máscara dinâmica no Endereço MAC (conversão automática para maiúsculas e inserção dos delimitadores : a cada 2 caracteres hexadecimais).

Validações de integridade:

Bloqueio contra duplicidade de Nº de Série.

Bloqueio contra IPs duplicados dentro da mesma planta (permitindo o mesmo IP apenas entre plantas diferentes).

Busca Rápida e Inteligente:

Pesquisa combinada por Série, Nome Parcial (ex: CHR0001) ou Endereço MAC.

Detecção inteligente: se múltiplos equipamentos coincidirem com o termo digitado, botões de seleção rápida são exibidos para escolha com 1 clique.

Geração Dinâmica de QR Codes:

Conversão em tempo real dos parâmetros do coletor em QR Codes prontos para leitura na tela (Nome, IP, Gateway, DNS 1, DNS 2, Senha Wi-Fi).

Tratamento automático para remoção de acentuação e caracteres especiais, evitando falhas na decodificação do leitor Zebra.

Gerenciador de Nomes de Atalhos:

Modal exclusivo com grade fixa de 3 QR Codes por linha em tamanho ampliado (155x155px).

Separação e filtragem de atalhos por Planta.

Criação e exclusão dinâmica de atalhos com persistência direta no servidor.

Carga Rápida de Arquivos via USB (MTP):

Automação via Windows Shell MTP (Shell.Application).

Copia todos os arquivos da pasta local arquivos_carga diretamente para a pasta interna do coletor em:
Este Computador\MC3300x\Divisão interna de armazenamento\Download

Dispensa depuração USB/ADB ou intervenção manual no Windows Explorer.

Interface Moderna & Produtividade:

Alternância entre Tema Claro e Tema Escuro (Dark Mode com paleta roxa estilizada).

Indicador visual em tempo real de status do servidor local (● Servidor local ativo / ● Servidor offline).

Botão para criar automaticamente o atalho com o ícone personalizado (icone.ico) na Área de Trabalho do Windows.

📁 Estrutura de Arquivos do Projeto
Plaintext
central-coletores/
│
├── Servidor_Central.ps1       # Servidor HTTP local leve desenvolvido em PowerShell
├── iniciar_central.bat        # Script de inicialização rápida com privilégios adequados
├── index.html                 # Interface SPA completa (HTML5, CSS3, JavaScript Vanilla)
├── coletores.json             # Banco de dados local em formato JSON
├── icone.ico                  # Ícone personalizado da aplicação
├── logo-roxo.png              # Logo para tema claro
├── logo-branco.png            # Logo para tema escuro
└── arquivos_carga/            # Pasta onde são colocados os arquivos para push USB (APKs, configs, etc.)
⚙️ Pré-requisitos
Sistema Operacional: Windows 10 ou Windows 11.

PowerShell: PowerShell 5.1 ou superior (nativo do Windows).

Navegador: Qualquer navegador moderno (Google Chrome, Microsoft Edge, Firefox).

Cabo USB: Conexão do coletor Zebra MC3300x em modo "Transferência de arquivo" (MTP).

🛠️ Como Executar o Sistema
Iniciar a aplicação:

Dê um duplo clique no arquivo iniciar_central.bat.

O PowerShell iniciará o servidor local na porta 5454 e abrirá a aplicação automaticamente no navegador padrão (http://localhost:5454).

Criar Atalho na Área de Trabalho:

Com o sistema aberto, clique no botão 🖥️ Criar Atalho no canto superior direito.

Um atalho estilizado com icone.ico será criado na sua Área de Trabalho apontando para o inicializador.

📲 Fluxo de Homologação / Staging (Zebra MC3300x)
Carga de Arquivos:

Coloque os arquivos necessários (instaladores .apk, certificados, perfis) dentro da pasta arquivos_carga.

Conecte o MC3300x no computador via USB.

Desbloqueie o coletor e confirme se a opção USB está em "Transferência de arquivo".

No topo da Central, clique em 📥 Enviar Arquivos USB. Os arquivos serão transferidos automaticamente para a pasta Download do aparelho.

Configuração de Rede:

Busque pelo nome ou série do equipamento no campo de pesquisa.

Com a câmera/leitor do Zebra, escaneie os QR Codes exibidos na tela para configurar IP, Gateway, DNS e Wi-Fi de forma ágil e sem digitação manual.

💾 Estrutura do Arquivo coletores.json
Os dados são armazenados localmente e atualizados de forma atômica pelo servidor:

JSON
{
  "plantas": [
    {
      "id": "planta_1700000000000",
      "nome": "Matriz - Sorocaba",
      "gateway": "192.168.1.1",
      "dns1": "8.8.8.8",
      "dns2": "8.8.4.4",
      "senhaWifi": "MinhaSenhaWifi"
    }
  ],
  "coletores": [
    {
      "id": 1,
      "nome": "CHR0001 - Expedição",
      "serie": "12345678901234",
      "mac": "00:1A:2B:3C:4D:5E",
      "ip": "192.168.1.105",
      "plantaId": "planta_1700000000000"
    }
  ],
  "atalhos": [
    {
      "id": "atalho_1700000000001",
      "nome": "RECEBIMENTO-DOCA-01",
      "plantaId": "planta_1700000000000"
    }
  ]
}
🔒 Segurança e Resiliência Local
Sem dependências externas: O backend não requer Node.js, Python, IIS ou bancos relacionais; utiliza apenas recursos nativos do PowerShell (System.Net.HttpListener).

Validação de Entrada: Tratamento contra injeção e sanitização de quebras de linha em respostas HTTP.

Tratamento de Timeout MTP: Mecanismo de leitura com fallback seguro no front-end para evitar falso-positivo em transferências de pacotes grandes.