# Задание 4 - Проектирование продажи ОСАГО

## Краткое описание решений

### 1. osago-aggregator сервис

**Функциональность:**
- Получает заявки на ОСАГО от core-app через Kafka
- Отправляет запросы во все 10 страховых компаний параллельно
- Делает polling предложений каждые 5 секунд
- Публикует полученные предложения в Kafka сразу же

**Хранилище данных: ДА (Redis)**

**Что хранится:**
- Активные заявки (TTL 1 час)
- Статус запросов к страховым компаниям
- Полученные предложения
- Distributed locks для координации между репликами

**Зачем:**
- Tracking статуса (опрос страховых компаний)
- Retry при ошибках
- Восстановление после падения
- Координация между множественными экземплярами

### 2. API osago-aggregator

**Event-Driven подход:**

**Consumer (Kafka):**
```yaml
Topic: osago.applications.created
Event: OsagoApplicationCreated
```

**Producer (Kafka):**
```yaml
Topic: osago.offers.received
Event: OsagoOfferReceived (публикуется для каждого предложения сразу)

Topic: osago.applications.completed
Event: OsagoApplicationCompleted (публикуется после 60 сек или когда все ответили)
```

### 3. Интеграция core-app - osago-aggregator

**Event-Driven через Kafka (асинхронно)**

**Почему:**
- Loose coupling - сервисы независимы
- Асинхронность - core-app не блокируется на 60 секунд
- Масштабируемость - multiple instances через consumer groups
- Надежность - guaranteed delivery

**Flow:**
```
core-app → Kafka: OsagoApplicationCreated
osago-aggregator ← Kafka: receives event
osago-aggregator → Insurance Companies (10 параллельных запросов)
osago-aggregator → Kafka: OsagoOfferReceived (для каждого)
core-app ← Kafka: receives offers
core-app → Web App: streaming через SSE
```

### 4. API для веб-приложения

**REST для создания заявки:**
```http
POST /api/v1/osago/applications
Response: applicationId, streamUrl
```

**Server-Sent Events (SSE) для streaming предложений:**
```http
GET /api/v1/osago/applications/{id}/stream
Content-Type: text/event-stream

event: offer
data: {"offerId": "...", "companyName": "Росгосстрах", "premium": 8500}

event: completed
data: {"totalOffersReceived": 7, "status": "COMPLETED"}
```

**Почему SSE, а не WebSocket:**
- Проще в реализации
- Автоматический reconnect
- HTTP/2 поддержка
- Подходит для one-way streaming
- Достаточно для use case (только server → client)

### 5. Интеграция Web App - core-app

**Server-Sent Events (SSE)**

**Отображается на диаграмме новой стрелкой:**
- Пунктирная линия (SSE stream)
- От core-app к Web App
- Label: "SSE: real-time offers"

### 6. Паттерны отказоустойчивости

#### 6.1. Rate Limiting

**Где:** osago-aggregator → Страховые компании

**Конфигурация:**
- 100 запросов в секунду на каждую компанию
- Distributed через Redis (учет всех реплик)

**На диаграмме:** Обозначение "Rate Limiter: 100 RPS"

#### 6.2. Circuit Breaker

**Где:** osago-aggregator → Страховые компании

**Конфигурация:**
- Открывается при 50% failure rate
- Ждет 30 секунд before retry (HALF_OPEN)
- Sliding window: последние 10 запросов

**States:**
- CLOSED: нормальная работа
- OPEN: сбой, fail-fast (не тратим ресурсы)
- HALF_OPEN: тест восстановления

**На диаграмме:** Обозначение "Circuit Breaker"

#### 6.3. Retry

**Где:** osago-aggregator → Страховые компании (GET offers)

**Конфигурация:**
- Max 3 попытки
- Exponential backoff: 2s, 4s
- Только для GET (идемпотентно)
- НЕ для POST (создание заявки)

**На диаграмме:** Обозначение "Retry: 3x"

#### 6.4. Timeout

**Где:** Все HTTP вызовы

**Конфигурация:**
- Per-request: 10 секунд
- Global для всей операции: 60 секунд
- Connect timeout: 3 секунды

**На диаграмме:** Обозначение "Timeout: 60s"

### 7. Replicas

**core-app:** 3-10 replicas (HPA)  
**osago-aggregator:** 2-5 replicas (HPA)

**Решения для stateful операций:**

#### Distributed State (Redis)
- Locks для координации polling между репликами
- Только одна replica обрабатывает конкретную заявку

#### Redis Pub/Sub для SSE
- Kafka event приходит в одну replica
- Broadcast через Redis Pub/Sub во все replicas
- SSE connection может быть на любой replica

#### Distributed Rate Limiter
- Учет лимитов через Redis
- Все replicas используют общий счетчик
- Лимит на уровне всего кластера, а не per-replica

## Отказоустойчивость

**Сценарии отказа:**

### 1. Страховая компания недоступна
- Circuit Breaker открывается
- Быстрый fail-fast (не тратим ресурсы)
- Пользователь получает предложения от остальных 9 компаний
- После 30 сек - попытка восстановления

### 2. osago-aggregator replica падает
- Distributed lock в Redis освобождается (TTL 2 минуты)
- Другая replica подхватывает обработку
- Polling продолжается с того же места

### 3. core-app replica падает (SSE connection)
- Browser auto-reconnect через SSE
- Подключается к другой replica
- Redis Pub/Sub обеспечивает доставку на любую replica

### 4. Kafka недоступен
- Events накапливаются в буфере producer
- После восстановления - автоматическая отправка
- Guaranteed delivery

