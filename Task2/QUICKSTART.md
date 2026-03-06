# Задание 2

## Требования

- Minikube установлен и запущен
- kubectl установлен
- Python 3.x и pip установлены
- Locust установлен (`pip install locust`)

## Пошаговая инструкция

### Шаг 1: Запуск Minikube и настройка

```bash
minikube start
minikube addons enable metrics-server
minikube status
```

### Шаг 2: Применение конфигураций

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml

minikube service scaletestapp-service --url
# Запомните этот URL!
```

### Шаг 3: Запуск мониторинга (в отдельном терминале)

```bash
kubectl get hpa scaletestapp-hpa --watch
```

### Шаг 4: Запуск нагрузочного тестирования

```bash
cd Task2
locust

# Откройте браузер: http://localhost:8089
# Введите:
#   - Host: URL из шага 2
#   - Number of users: 50-1000
#   - Spawn rate: 10
# Нажмите "Start"
```

### Шаг 5: Наблюдение за результатами

Вы должны увидеть:
- Увеличение числа реплик в HPA (1 → 2 → 4 → ... → max 10)
- Утилизацию памяти около 80%
- Создание новых подов

### Шаг 6: Остановка и очистка

```bash
# Остановить Locust (Ctrl+C)
# Подождать 2-3 минуты

# Очистка ресурсов
./cleanup.sh

# Или вручную:
kubectl delete -f hpa.yaml
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
```

## Сбор результатов

### Скриншоты Dashboard

```bash
minikube dashboard
```

Cкриншоты:
- Workloads → Deployments → scaletestapp (показывает количество реплик)
- Horizontal Pod Autoscalers (показывает метрики HPA)

### Логи из командной строки

```bash
# События HPA
kubectl describe hpa scaletestapp-hpa > hpa-results.log

# Статус подов
kubectl get pods -o wide > pods-results.log
```


