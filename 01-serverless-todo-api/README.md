# Serverless To-Do API - AWS

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Cognito](https://img.shields.io/badge/Amazon%20Cognito-DD344C?style=for-the-badge&logo=amazon-aws&logoColor=white)
![DynamoDB](https://img.shields.io/badge/DynamoDB-4053D6?style=for-the-badge&logo=amazon-dynamodb&logoColor=white)

## Contexto do problema

Imagine uma startup construindo uma aplicação de to-do list, onde usuários precisam se inscrever, fazer login e salvar suas tarefas privadas. Alguém precisa construir a API que dá vida a esse frontend e o ponto de partida já muda a forma de pensar o projeto: **não estamos construindo uma função Lambda isolada, estamos construindo uma API segura.**

O entry point é o API Gateway, mas antes que qualquer requisição consiga alcançá-lo, o usuário precisa estar autenticado por isso o Amazon Cognito entra na arquitetura, cuidando de registro e login de usuários. A partir daí, o API Gateway usa um Lambda Authorizer para verificar o token do usuário *antes* de qualquer lógica de negócio ser executada. Só quando autorizado, o request chega às funções Lambda de backend (em Python), responsáveis por realizar as operações de Create, Read, Update e Delete (CRUD). Por fim, os dados são armazenados em um banco NoSQL DynamoDB usando princípios de Single Table Design, para explorar a modelagem de dados a fundo.

Com isso, o projeto existe para provar domínio em três frentes que qualquer entrevistador técnico de Cloud vai perguntar sobre: **autenticação e autorização**, **compute stateless com Lambda**, e **modelagem de dados NoSQL**.

## Visão geral

Uma API REST serverless e segura para um aplicativo de tarefas (to-do list), onde usuários se cadastram, autenticam e gerenciam suas próprias tarefas com isolamento de dados garantido no nível da arquitetura, não apenas na lógica de negócio.

## Arquitetura

```
                                   ┌──────────────────┐
                                   │  Amazon Cognito   │
                                   │  (User Pool)       │
                                   └─────────┬──────────┘
                                             │ sign-up / login
                                             │ (emite JWT)
                                             ▼
┌────────────┐      ┌──────────────────┐      ┌─────────────────────┐
│   Client    │─────▶│   API Gateway     │─────▶│  Lambda Authorizer    │
│ (Postman/   │      │   (HTTP API)      │◀─────│  (valida assinatura   │
│  frontend)  │      │                  │      │   JWT via JWKS)       │
└────────────┘      └────────┬─────────┘      └─────────────────────┘
                              │ Allow + username no contexto
                              ▼
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼               ▼
        ┌───────────┐  ┌───────────┐   ┌───────────┐   ┌───────────┐
        │  Create    │  │   Read     │   │  Update    │   │  Delete    │
        │  Task      │  │   Tasks    │   │  Task      │   │  Task      │
        │ (Lambda)   │  │  (Lambda)  │   │ (Lambda)   │   │ (Lambda)   │
        └─────┬─────┘  └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
              └──────────────┴───────────────┴───────────────┘
                                     │
                                     ▼
                          ┌───────────────────┐
                          │     DynamoDB       │
                          │  (Single Table     │
                          │      Design)        │
                          └───────────────────┘
```

## Por que esses serviços e não outros?!

Essa é a parte que mais importa deste README. A diferença está em saber justificar cada escolha e seus trade-offs.

### API Gateway - HTTP API, não REST API

Optei pelo **HTTP API** (`aws_apigatewayv2_api`) em vez do REST API (v1) por dois motivos práticos: custo (**$1,00 por milhão de requisições** contra **$3,50** do REST API) e simplicidade de configuração para autenticação via JWT/Lambda Authorizer.

**Trade-off consciente:** o AWS WAF não se conecta diretamente a HTTP APIs, só a REST APIs, ALB, CloudFront e AppSync. Isso significa que esta API não tem uma camada de WAF na frente hoje. Para um ambiente de produção real, a evolução natural seria migrar para REST API (aceitando o custo maior) ou colocar CloudFront na frente do HTTP API (herdando WAF por ali). Para o escopo deste projeto, o custo-benefício do HTTP API venceu e documentar essa decisão é mais valioso do que fingir que a arquitetura é "perfeita".

### Cognito - gerenciamento de identidade, não autenticação própria

Não construí um sistema de login/senha próprio (hash de senha, tabela de usuários, recuperação de senha, etc.) porque isso é **exatamente o tipo de problema que já foi resolvido, testado e endurecido por anos** por um serviço gerenciado. Reinventar isso adicionaria risco de segurança sem agregar nada ao propósito do projeto, que é mostrar como *integrar* identidade a uma API, não como *construir* um provedor de identidade do zero.

### Lambda Authorizer customizado - não o Cognito Authorizer nativo do API Gateway

Aqui existia um caminho mais fácil: o API Gateway tem um **Cognito JWT Authorizer nativo**, que valida o token sem nenhuma linha de código. Eu optei deliberadamente por escrever um **Lambda Authorizer customizado** em vez disso.

Motivo: o Cognito Authorizer nativo esconde todo o processo de validação, você não vê o que está acontecendo. Escrever o Authorizer manualmente (buscar as chaves públicas do Cognito via JWKS, verificar assinatura RSA, checar expiração e audience do token, montar a IAM Policy de retorno) força entender e conseguir explicar exatamente **como** um JWT é validado, não só que "funciona".

### Lambda + Python - compute stateless, sem servidor para gerenciar

Cada operação do CRUD é uma função Lambda separada (não uma função monolítica com `if/else` de rota) para manter responsabilidade única por função, facilita leitura, teste e ajuste de permissões IAM específicas por operação. Python foi escolhido por ser a linguagem mais comum em vagas de Cloud/DevOps júnior no mercado atual, e por ter suporte nativo e maduro ao SDK da AWS (`boto3`).

### DynamoDB com Single Table Design - não RDS, não múltiplas tabelas

Três decisões aqui, cada uma com motivo diferente:

1. **NoSQL em vez de relacional (RDS):** o padrão de acesso da aplicação é simples e previsível ("buscar todas as tarefas de um usuário"), sem necessidade de joins complexos entre entidades. Isso é exatamente o cenário onde DynamoDB entrega mais performance (latência de milissegundos, previsível) com menos operação (sem gerenciar instância de banco, patch, backup manual).

2. **Single Table Design em vez de uma tabela por entidade:** em vez de ter uma tabela `Users` e outra `Tasks` (exigindo duas consultas e lógica de junção na aplicação), toda a informação de um usuário e suas tarefas vive na mesma tabela, sob a mesma Partition Key (`PK = USER#<username>`). Isso permite recuperar o perfil e todas as tarefas de um usuário com uma **única Query**, ao custo de uma modelagem inicial mais criteriosa. É a abordagem recomendada por especialistas em DynamoDB (Alex DeBrie) para cargas de trabalho previsíveis como esta.

3. **PAY_PER_REQUEST em vez de capacidade provisionada:** sem tráfego previsível ainda (é um projeto de portfólio), pagar por requisição elimina o risco de sub ou super-provisionar capacidade, e o custo em baixo volume é próximo de zero.

## Modelo de dados

| PK | SK | Atributos |
|---|---|---|
| `USER#<username>` | `#PROFILE#<username>` | Username, Email, CreatedAt |
| `USER#<username>` | `TASK#<taskId>` | TaskId, Title, Status, CreatedAt |

Uma única `Query` com `PK = USER#<username>` retorna o perfil e todas as tarefas daquele usuário, sem scan, sem join, sem tabela separada.

## Segurança - o que existe e o que falta

O que a arquitetura já garante:

- Autenticação via Cognito (sem senha em texto puro, sem sistema de login próprio)
- Autorização por token JWT com **verificação criptográfica de assinatura** (não apenas decodificação)
- Isolamento de dados por usuário: o `username` é extraído do claim do token no Authorizer, nunca do corpo da requisição, impossível um usuário manipular o payload para acessar dado de outro
- IAM Role com *least privilege*: a policy do DynamoDB está restrita ao ARN exato da tabela e às 5 ações necessárias, sem uso de wildcard (`dynamodb:*`)
- Alerta de custo (AWS Budgets + SNS) configurado via IaC, notificando em 80% e 100% de um teto mensal

O que fica documentado como próximo passo (roadmap de hardening), em vez de fingido como resolvido:

- Sem WAF na frente da API (limitação do HTTP API - ver seção acima)
- Sem throttling por rota configurado explicitamente
- Sem access logging no API Gateway (hoje só há logs de execução das Lambdas via CloudWatch)
- Cognito com MFA opcional, não obrigatório
- CORS não configurado (a API ainda não está conectada a um frontend real)

## Infraestrutura como código

Todo o ambiente é provisionado via Terraform, nenhum recurso foi criado manualmente pelo console. Isso garante que o ambiente é reprodutível e versionável.

```bash
terraform init
terraform plan -out plan.out
terraform apply "plan.out"
```

**26 a 29 recursos** são criados (variando conforme módulo de budget incluído): API Gateway + rotas + integrations + authorizer, Cognito User Pool + Client, DynamoDB table, IAM Role + Policy, 5 Lambda Functions, e o módulo de alerta de custo (SNS + Budget).

## Evidência de funcionamento

A API foi validada ponta a ponta com os 4 métodos do CRUD, incluindo o caso negativo (requisição sem token):

| Teste | Cenário | Resultado |
|---|---|---|
| 1 | `POST /tasks` sem token | `401/403 Unauthorized` — bloqueio confirmado |
| 2 | `POST /tasks` com token válido | `201 Created`, item persistido no DynamoDB |
| 3 | `GET /tasks` com token válido | Lista contendo apenas as tarefas do usuário autenticado |
| 4 | `PUT /tasks/{taskId}` com token válido | `200 OK`, atributo atualizado |
| 5 | `DELETE /tasks/{taskId}` com token válido | `200 OK`, item removido |

<img width="1550" height="610" alt="teste-1-2-3-4-5-6-complete" src="https://github.com/user-attachments/assets/c23d3219-0a61-41d3-8277-0988c64c9de2" />


*(prints das execuções disponíveis na pasta `/screenshots` deste repositório)*

## Lições aprendidas

- **Diferença entre autorização nativa e customizada tem consequências reais no formato do evento.** Migrar de Cognito JWT Authorizer nativo para Lambda Authorizer customizado exige trocar `event["requestContext"]["authorizer"]["jwt"]["claims"]` por `event["requestContext"]["authorizer"]["lambda"][...]`, um detalhe fácil de esquecer em algum dos Lambdas do CRUD, e que gera erro 500 silencioso (sem log, porque a Lambda de negócio sequer chega a rodar corretamente) até ser identificado via CloudWatch Logs.
- **Cache de Authorizer no API Gateway pode mascarar bugs.** Como a política retornada pelo Authorizer é escopada por rota (`event["routeArn"]`), o cache padrão de 300 segundos pode reutilizar uma política válida apenas para a primeira rota chamada, retornando `Forbidden` em chamadas subsequentes com o mesmo token. Correção: usar wildcard (`/*/*`) no `Resource` da policy para cobrir todas as rotas da API sob o mesmo cache.
- **`aws_lambda_permission` é fácil de esquecer ao adicionar um novo recurso Lambda.** Um Authorizer sem a permissão explícita do API Gateway para invocá-lo gera erro genérico (500) sem nenhum log, porque a Lambda nunca chega a ser executada. `terraform state list` foi a ferramenta mais rápida para confirmar se o recurso realmente existia no state antes de investigar em outro lugar.
- **`--only-binary=:all:` evita problemas de compilação cruzada.** Empacotar dependências com extensões nativas (como `python-jose[cryptography]`) direto no WSL/Ubuntu pode gerar binários incompatíveis com o runtime Amazon Linux da Lambda; baixar o wheel pré-compilado para a plataforma correta (`manylinux2014_x86_64`) evita esse problema por completo.

---

---

<div align="center">

**Marcelo Carrara** · AWS Certified Cloud Practitioner | Cloud Analyst · Paraná, Brazil

<p align="center">
  <a href="https://www.linkedin.com/in/marcelocarrara96">
    <img src="https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white" />
  </a>
  <a href="mailto:marcelo.carrara96@hotmail.com">
    <img src="https://img.shields.io/badge/Outlook-0078D4?style=for-the-badge&logo=microsoft-outlook&logoColor=white" />
  </a>
</p>
