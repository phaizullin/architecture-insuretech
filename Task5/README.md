# Задание 5 - GraphQL API для client-info

## Проблема

**REST API client-info:**
- Карточка клиента: ~500 атрибутов
- Разные сценарии требуют разные наборы данных
- Множество endpoints: `/clients/{id}`, `/clients/{id}/documents`, `/clients/{id}/relatives`
- **Проблема:** Для получения полных данных нужно 3-4 запроса → **RPS увеличивается в 3-4 раза**
- **Проблема:** Каждый endpoint возвращает ВСЕ поля → overfetching, лишний трафик

## Решение: GraphQL

### Файлы решения:

1. **client-info-schema.graphql** - Полная GraphQL схема
2. **query-examples.md** - Примеры запросов и сравнение с REST

---

## Ключевые компоненты GraphQL схемы

### Типы (Types):

```graphql
type Client {
  id: ID!
  name: String!
  age: Int!
  email: String
  phone: String
  # ... другие поля
  
  # Lazy-loading связанных объектов
  documents: [Document!]!
  relatives: [Relative!]!
  contacts: [Contact!]!
}

type Document {
  id: ID!
  type: DocumentType!
  number: String!
  issueDate: String!
  expiryDate: String
  verificationStatus: VerificationStatus!
  # ... другие поля
}

type Relative {
  id: ID!
  relationType: RelationType!
  name: String!
  age: Int
  isBeneficiary: Boolean!
  beneficiaryShare: Int
  # ... другие поля
}
```

### Enums:

```graphql
enum DocumentType {
  PASSPORT
  DRIVER_LICENSE
  BIRTH_CERTIFICATE
  SNILS
  INN
  # ... другие типы
}

enum RelationType {
  SPOUSE
  CHILD
  PARENT
  SIBLING
  # ... другие типы
}

enum VerificationStatus {
  NOT_VERIFIED
  PENDING
  VERIFIED
  REJECTED
}
```

### Queries (чтение):

```graphql
type Query {
  # Получить клиента по ID
  client(id: ID!): Client
  
  # Поиск клиентов с фильтрацией
  clients(filter: ClientFilter, limit: Int, offset: Int): [Client!]!
  
  # Получить документы клиента
  documentsByClient(clientId: ID!): [Document!]!
  
  # Получить документы по типу
  documentsByType(clientId: ID!, type: DocumentType!): [Document!]!
  
  # Получить родственников
  relativesByClient(clientId: ID!): [Relative!]!
  
  # ... другие запросы
}
```

### Mutations (изменение):

```graphql
type Mutation {
  # Создание
  createClient(input: CreateClientInput!): Client!
  addDocument(input: AddDocumentInput!): Document!
  addRelative(input: AddRelativeInput!): Relative!
  
  # Обновление
  updateClient(id: ID!, input: UpdateClientInput!): Client!
  updateDocumentVerificationStatus(id: ID!, status: VerificationStatus!): Document!
  
  # Удаление
  deleteClient(id: ID!): Boolean!
  deleteDocument(id: ID!): Boolean!
  deleteRelative(id: ID!): Boolean!
}
```

---

## Примеры использования

### Сценарий 1: Только базовая информация

```graphql
query {
  client(id: "client-123") {
    id
    name
    age
    email
  }
}
```

**REST требует:** 1 запрос, возвращает 500 полей  
**GraphQL:** 1 запрос, возвращает 4 поля  
**Экономия трафика:** 99%

---

### Сценарий 2: Клиент + все документы

```graphql
query {
  client(id: "client-123") {
    id
    name
    age
    documents {
      type
      number
      issueDate
      verificationStatus
    }
  }
}
```

**REST требует:** 2 запроса (client + documents)  
**GraphQL:** 1 запрос  
**Снижение RPS:** 50%

---

### Сценарий 3: Полная карточка (клиент + документы + родственники)

```graphql
query {
  client(id: "client-123") {
    id
    name
    age
    email
    phone
    documents {
      type
      number
      issueDate
    }
    relatives {
      name
      relationType
      isBeneficiary
      beneficiaryShare
    }
  }
}
```

**REST требует:** 3 запроса (client + documents + relatives)  
**GraphQL:** 1 запрос  
**Снижение RPS:** 66%

---

### Сценарий 4: ОСАГО - только паспорт и водительское удостоверение

```graphql
query GetClientForOSAGO($clientId: ID!) {
  client(id: $clientId) {
    name
    birthDate
    inn
    address
  }
  
  # Фильтруем на сервере - только нужные документы
  documentsByType(clientId: $clientId, type: PASSPORT) {
    number
    issueDate
    issuedBy
    departmentCode
  }
}
```

**REST требует:** 2 запроса + фильтрация на клиенте  
**GraphQL:** 1 запрос, фильтрация на сервере  
**Снижение RPS:** 50%

---

## Преимущества решения

### 1. Снижение RPS

**Среднее снижение RPS: 50-70%**

При нагрузке 2500 пользователей:
- **REST:** 2500 × 3 запроса = 7500 RPS
- **GraphQL:** 2500 × 1 запрос = 2500 RPS
- **Снижение:** в 3 раза!

### 2. Снижение трафика

Пример: запрос только имени и email

- **REST:** ~500 полей × 100 байт = ~50 KB
- **GraphQL:** 2 поля × 100 байт = ~0.2 KB
- **Экономия:** 99%

Средний сценарий:
- **REST:** 3 запроса × 50 KB = 150 KB
- **GraphQL:** 1 запрос × 5 KB = 5 KB
- **Экономия:** 97%

### 3. Снижение latency

- **REST:** 3 запроса × 100ms = 300ms (3 round-trips)
- **GraphQL:** 1 запрос × 100ms = 100ms (1 round-trip)
- **Улучшение:** в 3 раза

### 4. Гибкость для разных клиентов

**Web App:**
```graphql
# Минимум для UI
{ id, name, email }
```

**Mobile App:**
```graphql
# Экономия мобильного трафика
{ id, name, phone }
```

**core-app:**
```graphql
# Полные данные для бизнес-логики
{ id, name, age, email, phone, documents { ... }, relatives { ... } }
```

**Один API для всех клиентов!**

### 5. Нет overfetching

**REST проблема:**
- Нужны: `name`, `email`
- Получаем: все 500 полей

**GraphQL:**
- Запрашиваем: `name`, `email`
- Получаем: `name`, `email`

### 6. Нет underfetching

**REST проблема:**
- Нужны: клиент + документы
- Требуется: 2 запроса

**GraphQL:**
- Запрашиваем: клиент с вложенными документами
- Получаем: всё в одном запросе

### 7. Сильная типизация

- Enum типы для статусов и типов документов
- Обязательные/опциональные поля (! в схеме)
- Автогенерация TypeScript типов
- IDE автодополнение

### 8. Самодокументированность

GraphQL схема = документация:
- Описание каждого поля (docstrings)
- Примеры использования
- Связи между типами
- Enum значения

### 9. Эволюция без breaking changes

- Добавление новых полей: не ломает существующие запросы
- Deprecated fields: `@deprecated(reason: "...")`
- Версионирование не требуется

### 10. Introspection

Автоматические инструменты:
- GraphQL Playground
- GraphiQL
- Apollo Studio
- Postman GraphQL

---