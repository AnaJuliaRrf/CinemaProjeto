# Ingressos de Cinema

- **Temática do aplicativo:** Cinema (entidade `IngressoCinema`)
- **Estudante:** Ana Júlia Ferreira Rodrigues
- **Link da API publicada:** https://SUBSTITUIR-PELA-URL-REAL.onrender.com
- **Repositório da API (cinema-api):** https://github.com/AnaJuliaRrf/cinema-api

## Descrição

Aplicativo Flutter para cadastrar e listar ingressos de cinema (valor do
ingresso e número da sala). Os ingressos ficam salvos no aparelho (SQLite) e
são enviados para uma API própria (Node.js + Express) que grava em PostgreSQL
no Render. O app funciona sem internet: o que não conseguiu ser enviado fica
como **Pendente** e pode ser sincronizado depois pelo botão
**Sincronizar pendentes**.

## Arquitetura

```
 Telas (lib/screens)
        │  só chamam o Repository
        ▼
 IngressoRepository (lib/repository)   ← decide entre local e remoto
        │                         │
        ▼                         ▼
 SQLite no aparelho        ApiService (lib/services) ── HTTP ──► cinema-api (Render)
 (lib/database)                                                       │
                                                                      ▼
                                                                  PostgreSQL
```

| Pasta             | Responsabilidade                                                    |
| ----------------- | ------------------------------------------------------------------- |
| `lib/models`      | `IngressoCinema` + conversores `toMap/fromMap` (SQLite) e `toJson/fromJson` (API) |
| `lib/database`    | `DatabaseHelper`: criação da tabela e comandos SQL                  |
| `lib/services`    | `ApiService`: chamadas HTTP (GET/POST `/ingressos`), timeout de 8 s |
| `lib/repository`  | `IngressoRepository`: estratégia offline-first e sincronização      |
| `lib/screens`     | Dashboard, lista de ingressos e formulário de cadastro             |
| `lib/components`  | `Editor` (campo de texto) e `IndicadorSincronizacao` (etiqueta)     |

O app **nunca** acessa o PostgreSQL diretamente, apenas a API.

## Rotas da API

| Método | Rota                      | Função                                   |
| ------ | ------------------------- | ---------------------------------------- |
| GET    | `/`                       | Teste de vida                            |
| GET    | `/teste-banco`            | Testa a conexão com o PostgreSQL         |
| GET    | `/criar-tabela-ingressos` | Cria a tabela `ingressos` (rodar uma vez) |
| GET    | `/ingressos`              | Lista os ingressos                       |
| POST   | `/ingressos`              | Cadastra um ingresso                     |

**POST `/ingressos`** (corpo em camelCase):

```json
{ "idCliente": "3f1c2a9e-8b7d-4c1e-9a2f-5d6e7f8a9b0c", "valor": 18.90, "numeroSala": 8 }
```

- `201`: ingresso criado.
- `200`: esse `idCliente` já existia; nada é duplicado.
- `400`: dados inválidos. `500`: erro interno (o app mantém o ingresso como pendente).

```json
{
  "mensagem": "Ingresso cadastrado com sucesso",
  "ingresso": { "id": 1, "id_cliente": "3f1c2a9e-...", "valor": "18.90", "numero_sala": 8 }
}
```

**GET `/ingressos`** (resposta em snake_case; `valor` vem como texto porque é
`numeric` no Postgres):

```json
[
  { "id": 1, "id_cliente": "3f1c2a9e-...", "valor": "18.90", "numero_sala": 8 }
]
```

## Funcionamento offline-first

1. **Cadastro:** o app gera um `idCliente` (UUID v4), grava o ingresso no
   SQLite e tenta enviá-lo para a API.
   - API respondeu 200/201 → o ingresso fica **Sincronizado** (verde).
   - Sem internet, timeout ou erro do servidor → o ingresso fica **Pendente**
     (laranja). Ele não se perde e continua lá ao fechar e reabrir o app.
2. **Listagem:** sempre lida do SQLite, por isso funciona sem internet. O topo
   da lista mostra o total de ingressos e quantos estão pendentes.
3. **Sincronizar pendentes:** envia os pendentes um a um e marca como
   sincronizados apenas os que a API confirmou. Depois, busca os ingressos
   remotos (`GET /ingressos`) e grava no aparelho. Como o `idCliente` é a chave
   nos dois lados, sincronizar várias vezes não duplica registros.

Fora do escopo: sincronização automática em segundo plano, resolução de
conflitos, edição/exclusão offline e autenticação.

## Como rodar

Requisitos: Flutter SDK e um emulador Android ou um aparelho conectado
(o `sqflite` não funciona no Flutter Web).

```bash
flutter pub get
flutter run
```

A URL da API fica em uma única constante, `urlBaseApi`, em
`lib/services/api_service.dart`.

Testes automatizados (Repository, ApiService, model e telas, com banco e API
simulados):

```bash
flutter test
```

> Observação: a API gratuita do Render "dorme" após um tempo sem uso. Abra a
> URL da API no navegador e aguarde ela responder antes de usar o app.
