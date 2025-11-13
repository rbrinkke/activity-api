# Migratie naar Centrale Database

**Datum:** 2025-11-13
**Status:** ✅ Compleet

## Wijzigingen

### 1. Docker Compose Configuratie

**Voor:**
- Eigen PostGIS/PostgreSQL container (postgis/postgis:15-3.3)
- Eigen netwerk (activities-network)
- Port 8000

**Na:**
- ✅ Gebruikt centrale `activity-postgres-db` container
- ✅ Gebruikt `activity-network` netwerk
- ✅ Port 8007 (om conflicten te voorkomen)
- ✅ Container naam: `activity-api`

### 2. Database Configuratie

**Database URL:**
```
postgresql://postgres:postgres_secure_password_change_in_prod@activity-postgres-db:5432/activitydb
```

**Belangrijke punten:**
- Host: `activity-postgres-db` (centrale database container)
- Database: `activitydb` (met alle 40 tabellen)
- Schema: `activity` (automatisch via migraties)
- User: `postgres`
- Password: `postgres_secure_password_change_in_prod`
- Connection pool: 10-50 connections
- Command timeout: 60 seconds

### 3. Netwerk Configuratie

Gebruikt `activity-network` external network:
- Alle activity services in zelfde netwerk
- Direct communicatie tussen services
- Geen port mapping conflicts

### 4. Container Naam

Container naam: `activity-api`
- Makkelijk te identificeren
- Consistent met andere services
- Gebruikt in logs en monitoring

## Database Schema

De activity-api gebruikt tabellen uit het centrale schema:

**Activity Tabellen:**
- `activities` (24 kolommen) - Core activity data met geo-locatie
- `activity_participants` (10 kolommen) - Participant management
- `activity_tags` (4 kolommen) - Activity categorization
- `activity_images` (8 kolommen) - Activity photos
- `activity_comments` (7 kolommen) - Activity discussions

**Location Tabellen:**
- PostGIS extensie voor geo-spatial queries
- POINT geometrie voor latitude/longitude
- Spatial indexes voor snelle proximity searches

**User Tabellen:**
- `users` (34 kolommen) - User profiles
- `user_settings` (14 kolommen) - User preferences

## Deployment

### Starten

```bash
cd /mnt/d/activity/activity-api
docker compose build
docker compose up -d
```

### Logs Checken

```bash
docker compose logs -f activity-api
```

### Health Check

```bash
curl http://localhost:8007/health
```

### Stoppen

```bash
docker compose down
```

## Belangrijke Opmerkingen

1. **Geen eigen database meer** - Alle data in centrale database
2. **PostGIS functionaliteit** - Centrale database heeft PostGIS extensie
3. **Port 8007** - Om conflict met andere APIs te voorkomen
4. **External network** - Moet `activity-network` netwerk bestaan
5. **Connection pooling** - 10-50 database connections voor performance

## Port Overzicht

| Service | Port | Functie |
|---------|------|---------|
| auth-api | 8000 | Authenticatie & gebruikers |
| moderation-api | 8002 | Content moderatie |
| community-api | 8003 | Communities & posts |
| participation-api | 8004 | Activity deelname |
| social-api | 8005 | Social features |
| notifications-api | 8006 | Notificaties |
| activity-api | 8007 | Activity CRUD & geo-search |

## Verificatie

Checklist na deployment:
- [ ] Container start zonder errors
- [ ] Database connectie succesvol
- [ ] PostGIS extensie beschikbaar
- [ ] Health endpoint reageert
- [ ] Auth-API communicatie werkt
- [ ] Activity endpoints werken
- [ ] Geo-spatial queries werken

## Rollback

Als er problemen zijn:
```bash
cd /mnt/d/activity/activity-api
docker compose down
# Fix issues
docker compose up -d
```

---

**Status:** ✅ Klaar voor gebruik met centrale database
