# Примеры GraphQL запросов для client-info

## Сравнение REST vs GraphQL

### Сценарий 1: Получить только базовую информацию о клиенте

#### REST (1 запрос):
```http
GET /v1/clients/client-123
```

Проблема: возвращает ВСЕ поля клиента (500 атрибутов), даже если нужны только имя и возраст.

#### GraphQL (1 запрос):
```graphql
query {
  client(id: "client-123") {
    id
    name
    age
  }
}
```

Возвращает **только** запрошенные поля!

---

### Сценарий 2: Получить клиента + все его документы

#### REST (2 запроса):
```http
GET /v1/clients/client-123
GET /v1/clients/client-123/documents
```

Проблема: 2 запроса, 2 round-trips к серверу.

#### GraphQL (1 запрос):
```graphql
query {
  client(id: "client-123") {
    id
    name
    age
    email
    documents {
      id
      type
      number
      issueDate
      expiryDate
      verificationStatus
    }
  }
}
```

Всё в одном запросе!

---

### Сценарий 3: Получить клиента + документы + родственников

#### REST (3 запроса):
```http
GET /v1/clients/client-123
GET /v1/clients/client-123/documents
GET /v1/clients/client-123/relatives
```

Проблема: 3 запроса, увеличение RPS в 3 раза!

#### GraphQL (1 запрос):
```graphql
query {
  client(id: "client-123") {
    id
    name
    age
    email
    phone
    documents {
      id
      type
      number
      issueDate
      verificationStatus
    }
    relatives {
      id
      name
      relationType
      age
      isBeneficiary
      beneficiaryShare
    }
  }
}
```

Всё в одном запросе! RPS не увеличивается.

---

### Сценарий 4: Только паспортные данные клиента

#### REST (2 запроса + фильтрация на клиенте):
```http
GET /v1/clients/client-123
GET /v1/clients/client-123/documents
# Клиент фильтрует массив документов по type=PASSPORT
```

Проблема: возвращает ВСЕ документы, клиент фильтрует локально.

#### GraphQL (1 запрос):
```graphql
query {
  client(id: "client-123") {
    name
    birthDate
  }
  documentsByType(clientId: "client-123", type: PASSPORT) {
    number
    issueDate
    expiryDate
    issuedBy
    departmentCode
    placeOfBirth
  }
}
```

Фильтрация на сервере, возвращает только паспорт!

---

## Примеры запросов для разных сценариев

### 1. Оформление страховки ОСАГО

**Нужны:** имя, дата рождения, паспорт, водительское удостоверение

```graphql
query GetClientForOSAGO($clientId: ID!) {
  client(id: $clientId) {
    id
    name
    birthDate
    inn
    snils
    address
    
    # Только паспорт и водительское удостоверение
    documents {
      id
      type
      number
      issueDate
      expiryDate
      issuedBy
      departmentCode
      placeOfBirth
    }
  }
}

# Variables:
# { "clientId": "client-123" }
```

**REST эквивалент:**
- GET /v1/clients/client-123 (возвращает 500 атрибутов!)
- GET /v1/clients/client-123/documents (возвращает все документы)
- Клиент фильтрует документы локально

**Результат:** 2 запроса vs 1 запрос GraphQL

---

### 2. Страхование жизни с бенефициарами

**Нужны:** базовая информация + родственники-бенефициары

```graphql
query GetClientForLifeInsurance($clientId: ID!) {
  client(id: $clientId) {
    id
    name
    age
    birthDate
    email
    phone
    
    # Только родственники, которые являются бенефициарами
    relatives {
      id
      name
      relationType
      age
      birthDate
      isBeneficiary
      beneficiaryShare
    }
  }
}
```

**REST эквивалент:**
- GET /v1/clients/client-123
- GET /v1/clients/client-123/relatives
- Фильтрация на клиенте

**Результат:** 2 запроса vs 1 запрос GraphQL

---

### 3. Личный кабинет - минимальная информация

**Нужны:** только имя, email, телефон для отображения в header

```graphql
query GetClientHeaderInfo($clientId: ID!) {
  client(id: $clientId) {
    id
    name
    email
    phone
  }
}
```

**REST эквивалент:**
- GET /v1/clients/client-123 (возвращает все 500 атрибутов!)

**Результат:** 
- REST: передано ~500 полей, использовано 4
- GraphQL: передано 4 поля, использовано 4

GraphQL экономит трафик в 125 раз!

---

### 4. Полная карточка клиента (админка)

**Нужны:** вообще всё

```graphql
query GetFullClientCard($clientId: ID!) {
  client(id: $clientId) {
    id
    name
    age
    email
    phone
    address
    birthDate
    inn
    snils
    createdAt
    updatedAt
    
    documents {
      id
      type
      number
      issueDate
      expiryDate
      issuedBy
      departmentCode
      placeOfBirth
      scanUrl
      verificationStatus
    }
    
    relatives {
      id
      relationType
      name
      age
      birthDate
      phone
      email
      isBeneficiary
      beneficiaryShare
    }
    
    contacts {
      id
      name
      contactType
      phone
      email
      note
    }
  }
}
```

**REST эквивалент:**
- GET /v1/clients/client-123
- GET /v1/clients/client-123/documents
- GET /v1/clients/client-123/relatives
- GET /v1/clients/client-123/contacts (если есть)

**Результат:** 3-4 запроса vs 1 запрос GraphQL

---

### 5. Поиск клиентов по фильтрам

```graphql
query SearchClients($filter: ClientFilter!, $limit: Int!) {
  clients(filter: $filter, limit: $limit) {
    id
    name
    age
    email
    phone
    inn
  }
}

# Variables:
# {
#   "filter": {
#     "name": "Иванов",
#     "minAge": 18,
#     "maxAge": 65
#   },
#   "limit": 10
# }
```

---

### 6. Создание нового клиента с документами

```graphql
# Шаг 1: Создать клиента
mutation CreateNewClient($input: CreateClientInput!) {
  createClient(input: $input) {
    id
    name
    email
    createdAt
  }
}

# Variables:
# {
#   "input": {
#     "name": "Иван Петров",
#     "age": 35,
#     "email": "ivan.petrov@example.com",
#     "phone": "+79001234567",
#     "birthDate": "1988-05-15",
#     "inn": "123456789012",
#     "address": "Москва, ул. Ленина, д. 1"
#   }
# }

# Шаг 2: Добавить паспорт
mutation AddPassport($input: AddDocumentInput!) {
  addDocument(input: $input) {
    id
    type
    number
    issueDate
    verificationStatus
  }
}

# Variables:
# {
#   "input": {
#     "clientId": "client-123",
#     "type": "PASSPORT",
#     "number": "1234 567890",
#     "issueDate": "2010-05-15",
#     "expiryDate": null,
#     "issuedBy": "УФМС России по г. Москва",
#     "departmentCode": "770-001",
#     "placeOfBirth": "г. Москва"
#   }
# }
```

---

### 7. Обновление информации клиента

```graphql
mutation UpdateClientContacts($id: ID!, $input: UpdateClientInput!) {
  updateClient(id: $id, input: $input) {
    id
    email
    phone
    address
    updatedAt
  }
}

# Variables:
# {
#   "id": "client-123",
#   "input": {
#     "email": "new.email@example.com",
#     "phone": "+79009999999",
#     "address": "Санкт-Петербург, Невский пр., д. 100"
#   }
# }
```

---
