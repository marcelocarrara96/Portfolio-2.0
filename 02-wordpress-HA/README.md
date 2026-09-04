# WordPress de Alta Disponibilidade na AWS

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![CloudFormation](https://img.shields.io/badge/CloudFormation-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Aurora](https://img.shields.io/badge/Aurora_MySQL-527FFF?style=for-the-badge&logo=amazon-aws&logoColor=white)
![WordPress](https://img.shields.io/badge/WordPress-21759B?style=for-the-badge&logo=wordpress&logoColor=white)

## Contexto do problema

Imagine uma empresa que roda seu site WordPress em um único servidor EC2. Funciona bem até o servidor cair. Quando isso acontece, o site inteiro vai junto: banco de dados, arquivos de mídia, sessões ativas. Tudo. O tempo de recuperação depende de alguém perceber o problema, subir outro servidor, restaurar backup e reconfigurar tudo manualmente.

O objetivo deste projeto era eliminar cada um desses pontos únicos de falha, construindo uma arquitetura onde nenhum componente isolado derruba a aplicação inteira. Não é apenas sobre alta disponibilidade, é sobre entender **por que** cada camada existe e o que aconteceria se ela não estivesse lá.

## Visão geral

Uma aplicação WordPress production-ready distribuída em múltiplas Availability Zones, com banco de dados gerenciado e replicado automaticamente, armazenamento de arquivos compartilhado entre instâncias e escalabilidade automática baseada em demanda, tudo provisionado via Infrastructure as Code com CloudFormation.

## Arquitetura

```
Internet
    │
    ▼
Application Load Balancer (PublicSubnet1 + PublicSubnet2)
    │
    ├──── AZ 1 (AppSubnet1)          ├──── AZ 2 (AppSubnet2)
    │     EC2 WP-App                  │     EC2 WP-App
    │     (Auto Scaling Group)        │     (Auto Scaling Group)
    │              │                              │
    │              └──────────┬───────────────────┘
    │                         │
    │                    Amazon EFS
    │               (wp-content/uploads
    │                compartilhado)
    │
    ▼
Aurora MySQL Cluster
    ├── Writer Instance (AZ 1 - DatabaseSubnet1)
    └── Reader Instance (AZ 2 - DatabaseSubnet2)
```

## Por que esses serviços e não outros?

A diferença entre fazer e entender está em saber justificar cada escolha e seus trade-offs.

### CloudFormation para a infraestrutura de rede, não console manual

A VPC, subnets, route tables e security groups foram provisionados via template CloudFormation, não clicando no console. O motivo não é sofisticação técnica, é reprodutibilidade. Um ambiente criado manualmente existe apenas naquela conta, naquela região, naquele momento. Um template CloudFormation pode recriar o mesmo ambiente em minutos, em qualquer conta, sem depender de memória ou documentação desatualizada.

**Trade-off consciente:** CloudFormation tem curva de aprendizado e debugging pode ser lento (erros só aparecem durante o deploy). Para ambientes simples e experimentais, criar pelo console é mais rápido. Para qualquer coisa que precise existir por mais de um dia ou ser replicada, IaC é a escolha certa.

### Aurora MySQL, não RDS MySQL padrão e não EC2 com MySQL instalado

Três opções estavam disponíveis para o banco de dados. Cada uma com trade-offs diferentes:

**EC2 com MySQL instalado:** controle total sobre configuração, mas você gerencia patches, backups, replicação, failover e monitoramento. Em produção, isso é uma responsabilidade operacional significativa que raramente agrega valor ao negócio. OVERHEAD operacional.

**RDS MySQL:** banco gerenciado, backups automáticos, failover Multi-AZ. Boa escolha para a maioria dos casos.

**Aurora MySQL:** escolhido aqui porque oferece replicação automática entre instâncias Writer e Reader em AZs diferentes com failover em menos de 30 segundos, sem configuração adicional. O custo é ligeiramente maior que RDS MySQL padrão, mas para uma aplicação que precisa de alta disponibilidade real, o Aurora entrega isso nativamente.

O banco de dados foi colocado em **subnets privadas** sem acesso público. Só as instâncias EC2 associadas ao `RDSSecurityGroup` correto conseguem se conectar na porta 3306. Nenhuma conexão direta da internet chega ao banco.

### Amazon EFS, não EBS, não S3

Esse foi o ponto de decisão mais importante da camada de storage.

Quando o Auto Scaling Group sobe uma segunda instância EC2 para lidar com mais tráfego, ela precisa ter acesso aos mesmos arquivos de mídia e uploads que a primeira instância. Com **EBS**, cada instância tem seu próprio volume, os arquivos de uma não existem na outra. Com **S3**, seria necessário adaptar o WordPress para servir mídia via URL do S3, o que exige plugin adicional e configuração extra.

O **EFS** resolve isso de forma transparente: é um sistema de arquivos NFS que múltiplas instâncias montam simultaneamente. O WordPress não precisa saber que o storage é compartilhado, para ele, é só um diretório normal. Os uploads feitos em uma instância aparecem imediatamente em todas as outras.

**Trade-off consciente:** EFS tem latência ligeiramente maior que EBS para operações de I/O intensivas. Para uma aplicação WordPress com tráfego típico de leitura de conteúdo, essa diferença é imperceptível. Para um banco de dados ou aplicação que faz milhares de operações de escrita por segundo, EFS não seria a escolha adequada.

### Application Load Balancer, não Network Load Balancer, não Route 53 com health check

O ALB opera na camada 7 (HTTP/HTTPS), o que significa que ele entende o conteúdo das requisições. Isso permite que ele:
- Verifique se o WordPress está respondendo corretamente via `/wp-login.php` (não apenas se a porta está aberta)
- Distribua tráfego apenas para instâncias que passaram no health check
- Encerre sessões HTTPS no balanceador, aliviando as instâncias dessa responsabilidade (quando HTTPS for configurado)

O **Network Load Balancer** operaria na camada 4, mais rápido, mais barato, mas sem entendimento do protocolo HTTP. Para uma aplicação web, o ALB é a escolha natural.

### Auto Scaling Group com política de Target Tracking

O ASG foi configurado com capacidade desejada de 2 instâncias, mínimo de 2 e máximo de 4. O motivo para mínimo 2 (não 1) é garantir que a aplicação continue disponível enquanto uma instância falha e outra está sendo provisionada, com apenas 1 instância como mínimo, há uma janela de indisponibilidade durante esse processo.

A política de **Target Tracking** ajusta o número de instâncias automaticamente para manter uma métrica próxima de um valor alvo, sem precisar definir regras de escalar para cima e escalar para baixo separadamente. É mais simples de configurar e mais inteligente na prática do que políticas de step scaling manuais.

## O que existe e o que falta

**O que a arquitetura já garante:**
- Nenhum ponto único de falha na camada de aplicação (Auto Scaling em 2 AZs)
- Banco de dados com failover automático entre AZs em menos de 30 segundos (Aurora Multi-AZ)
- Armazenamento de arquivos compartilhado e disponível para todas as instâncias (EFS com targets em 2 AZs)
- Isolamento de rede: banco de dados inacessível da internet, apenas da camada de aplicação
- Health checks reais verificando resposta HTTP, não apenas conectividade TCP

**O que fica documentado como próximo passo:**
- Sem HTTPS configurado, o ALB escuta apenas na porta 80 hoje
- Sem WAF na frente do ALB, a aplicação WordPress está exposta a bots e ataques comuns sem filtragem
- Sem caching (ElastiCache ou CloudFront), cada requisição chega até o servidor de aplicação
- Sem alarmes de CloudWatch configurados para as métricas do ASG e do Aurora
- Sem política de backup testada, backups automáticos do Aurora existem, mas o processo de restore não foi validado

## Lições aprendidas

**A ordem de criação importa mais do que parece.** A VPC precisa existir antes das subnets, as subnets antes do banco de dados, o banco antes do launch template, o launch template antes do ASG. CloudFormation gerencia essa dependência automaticamente quando você usa `!Ref` e `!GetAtt` corretamente. Fazer isso manualmente pelo console exige lembrar dessa ordem toda vez, e esquecer um passo no meio significa desfazer e refazer.

**Security Group como fonte de tráfego é mais seguro do que CIDR.** A regra do RDS que permite conexão "do Security Group do EC2" em vez de "do range de IP das subnets" significa que somente instâncias explicitamente associadas àquele Security Group chegam ao banco. Uma EC2 nova na mesma subnet, sem o Security Group correto, não consegue se conectar. É controle de acesso baseado em identidade, não em localização de rede.

**EFS precisa de targets de montagem em cada AZ onde será usado.** Criar o EFS sem configurar targets nas AZs das subnets de aplicação resulta em erro de montagem nas instâncias. O target de montagem é o endpoint NFS dentro da AZ, sem ele, a instância não tem para onde apontar o comando de mount.

**O health check path do ALB precisa retornar 200 para a instância ser considerada saudável.** Configurar `/wp-login.php` como path de health check foi intencional: se o WordPress não está respondendo (banco de dados inacessível, processo PHP travado, configuração corrompida), essa página retorna erro e a instância é removida do pool automaticamente. Um health check em `/` seria menos precis, pode retornar 200 mesmo quando a aplicação está parcialmente quebrada.

**Parâmetros errados no launch template não aparecem como erro imediato.** O DNS do ALB passado incorretamente (com `http://` na frente ou com barra no final) não causa falha no deploy da stack, causa falha no carregamento de CSS e JavaScript do WordPress depois que tudo está rodando. O erro só aparece no browser, não nos logs do CloudFormation.

---

<div align="center">

**Marcelo Carrara** · AWS Certified Cloud Practitioner | Cloud Analyst · São Pualo, Brazil

<p align="center">
  <a href="https://www.linkedin.com/in/marcelo-carrara-tech">
    <img src="https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white" />
  </a>
  <a href="mailto:marcelo.carrara96@hotmail.com">
    <img src="https://img.shields.io/badge/Outlook-0078D4?style=for-the-badge&logo=microsoft-outlook&logoColor=white" />
  </a>
</p>

</div>
