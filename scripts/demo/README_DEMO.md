# Activity API Demo Scripts

Demo scripts voor sprint presentaties aan de directeur.

## 🌟 AANBEVOLEN: DEMO_GUIDE.md

**Complete handleiding met alle curl commando's voor handmatige demo**

```bash
cat DEMO_GUIDE.md
```

- ✅ Copy-paste ready - Alle commando's klaar om te gebruiken
- ✅ Database verificatie na elke stap
- ✅ Gestructureerd in 6 fasen, alle 19 endpoints
- ✅ Perfect voor live demo aan directeur

**Geschatte tijd:** 15-20 minuten

---

## Voor de Sprint Demo

### Pre-Demo Checklist (5 minuten)

```bash
# 1. Check services
docker ps | grep -E "postgres|auth-api|activity-api"

# 2. Health checks
curl http://localhost:8000/health  # auth-api
curl http://localhost:8007/health  # activity-api

# 3. Open demo guide
cat DEMO_GUIDE.md | less
```

### Demo Flow

1. **Voorbereiding** (in DEMO_GUIDE.md)
   - Maak demo user
   - Verkrijg JWT token

2. **6 Fasen** (copy-paste commando's)
   - Categories (3 endpoints)
   - Activities CRUD (5 endpoints)
   - Search & Discovery (4 endpoints)
   - Participants (2 endpoints)
   - Reviews (4 endpoints)
   - Tags (1 endpoint)

3. **Database Verificatie**
   - Na elke operatie database proof
   - Real-time data changes

**🎉 Succes met de demo!**

## Wat te Laten Zien

- 100% Stored Procedure Pattern
- Geo-spatial search (PostGIS)
- JWT authenticatie
- Privacy levels
- Review system
- Database bewijs bij elke stap

**Alle 19 endpoints + 6 database tabellen ✓**
