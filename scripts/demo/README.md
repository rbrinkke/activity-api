# Activity API - Sprint Demo Scripts 🚀

Professional demo scripts voor het testen van de Activity API met complete database verificatie bij elke stap.

## 📋 Overzicht

Deze demo scripts testen **alle functionaliteit** van de Activity API met:
- ✅ Real-time database verificatie
- ✅ Professional output met kleuren en formatting
- ✅ JWT token generatie
- ✅ Complete user journey (van setup tot reviews)
- ✅ Automatische en interactieve modes
- ✅ Comprehensive test reporting

## 🏗️ Architectuur

```
scripts/demo/
├── lib/                      # Shared libraries
│   ├── colors.sh            # Color output & formatting functions
│   ├── db.sh                # Database helper functions
│   └── api.sh               # API request helpers
├── 00-setup.sh              # Prerequisites & JWT token generation
├── run-full-demo.sh         # Complete end-to-end demo
├── .env.demo                # Generated environment (after setup)
└── README.md                # This file
```

## 🚀 Quick Start

### Stap 1: Run Setup

```bash
cd /mnt/d/activity/activity-api/scripts/demo
./00-setup.sh
```

Dit script:
- ✅ Controleert alle prerequisites (curl, jq, python3, docker)
- ✅ Verifieert dat activity-api en PostgreSQL draaien
- ✅ Genereert 3 test users met JWT tokens
- ✅ Slaat configuratie op in `.env.demo`

### Stap 2: Run Full Demo

```bash
./run-full-demo.sh
```

Of voor automatische mode (zonder pauses):

```bash
DEMO_MODE=auto ./run-full-demo.sh
```

## 🎯 Wat Wordt Getest?

### Phase 1: Category Management
- ✅ List all categories
- ✅ Create new category
- ✅ Database verification

### Phase 2: Activity Management
- ✅ Create multiple activities
- ✅ Get activity by ID
- ✅ Update activity
- ✅ Database state tracking

### Phase 3: Search & Discovery
- ✅ Text search (keyword filtering)
- ✅ Nearby search (geospatial)
- ✅ Personalized feed
- ✅ AI recommendations

### Phase 4: Participant Management
- ✅ List participants
- ✅ Check waitlist
- ✅ Participant count verification

### Phase 5: Review System
- ✅ Create reviews (multiple ratings)
- ✅ List reviews
- ✅ Review statistics (average rating)

### Phase 6: Tag System
- ✅ Get popular tags
- ✅ Tag usage statistics

### Phase 7: Advanced Features
- ✅ Activity cancellation
- ✅ Status updates
- ✅ Database consistency checks

## 📊 Output Format

Elke test toont:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 STEP 3: Create New Activity
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔷 ACTION: User creates "Weekend Hiking" activity
→ API Request: POST /activities

📊 DATABASE BEFORE:
   Activities count: 0

☁️ API RESPONSE:
   Status: 201
   {
     "id": "abc-123-def",
     "title": "Weekend Hiking",
     ...
   }

📊 DATABASE AFTER:
   Activities count: 1

   Activity Details:
   ┌─────────────┬──────────────────┐
   │ Field       │ Value            │
   ├─────────────┼──────────────────┤
   │ Title       │ Weekend Hiking   │
   │ Status      │ open             │
   │ Organizer   │ sarah@demo.com   │
   └─────────────┴──────────────────┘

✓ Verification: Activity created successfully!
```

## 🎭 Demo Modes

### Interactive Mode (default)
```bash
./run-full-demo.sh
```
- Pauzeer na elke stap
- Perfect voor live presentaties
- "Press ENTER to continue" prompts

### Automatic Mode
```bash
DEMO_MODE=auto ./run-full-demo.sh
```
- Automatisch doorlopen
- 1-2 seconden tussen stappen
- Perfect voor opnames of CI/CD

## 👥 Test Users

De setup creëert 3 users:

1. **Sarah** (sarah@demo.com)
   - Role: Organizer
   - Subscription: Premium
   - Creates activities

2. **John** (john@demo.com)
   - Role: Participant
   - Subscription: Free
   - Joins activities, leaves reviews

3. **Emma** (emma@demo.com)
   - Role: Participant
   - Subscription: Free
   - Joins activities, leaves reviews

Alle users krijgen JWT tokens met 7 dagen geldigheid.

## 🔧 Configuration

### Environment Variables

Set in `.env.demo` (automatically generated):

```bash
# API Configuration
API_BASE_URL='http://localhost:8007'
DEMO_MODE='interactive'  # or 'auto'

# Database Configuration
DB_CONTAINER='activity-postgres-db'
DB_USER='postgres'
DB_NAME='activitydb'

# JWT Secret (moet matchen met activity-api)
JWT_SECRET_KEY='dev-secret-change-in-production'

# Test Users (auto-generated)
USER1_ID='...'
USER1_EMAIL='sarah@demo.com'
USER1_TOKEN='...'
...
```

## 📈 Final Summary

Na de demo zie je een complete samenvatting:

```
🏆 DEMO COMPLETE 🏆

┌─────────────────────────────────────────────┐
│ Total Duration      │ 3m 42s                │
│ Tests Executed      │ 28                    │
│ Tests Passed        │ 28                    │
│ Tests Failed        │ 0                     │
│ Success Rate        │ 100%                  │
└─────────────────────────────────────────────┘

📊 DATABASE STATE:
   Categories: 5
   Activities: 8
   Participants: 12
   Reviews: 15
   Tags: 5

✓ ALL TESTS PASSED! ✓
```

## 🛠️ Troubleshooting

### "activity-api is not running"
```bash
cd /mnt/d/activity/activity-api
docker compose up -d
```

### "PostgreSQL container is not running"
```bash
cd /mnt/d/activity
./scripts/start-infra.sh
```

### "PyJWT not found"
```bash
pip3 install PyJWT
```

### "Cannot connect to database"
Check dat activity-postgres-db container draait:
```bash
docker ps | grep activity-postgres-db
```

### Database Queries Falen
Verify database access:
```bash
docker exec activity-postgres-db psql -U postgres -d activitydb -c "SELECT 1;"
```

## 📝 Custom Tests

Je kunt individuele functies uit de libraries gebruiken:

```bash
# Source the libraries
source scripts/demo/lib/colors.sh
source scripts/demo/lib/db.sh
source scripts/demo/lib/api.sh

# Load environment
source scripts/demo/.env.demo

# Use helper functions
show_database_summary
show_activities 5
api_get "/activities/search?query=hiking" "$USER1_TOKEN"
```

## 🎨 Color Codes

- **GREEN** (✓): Success, passed tests
- **RED** (✗): Errors, failed tests
- **YELLOW**: Headers, warnings
- **BLUE**: Database sections, info
- **CYAN**: Actions, user interactions
- **MAGENTA**: Step indicators

## 📚 Dependencies

Required:
- `bash` (4.0+)
- `curl`
- `python3` met `PyJWT` package
- `docker` (voor database queries)

Optional (maar aanbevolen):
- `jq` (voor mooiere JSON output)

## 🔒 Security Notes

⚠️ **BELANGRIJK**: Deze demo scripts zijn voor **development/testing only**!

- JWT tokens worden lokaal gegenereerd (niet via auth-api)
- Test users zijn fictief
- Gebruik NOOIT in productie
- JWT_SECRET moet matchen tussen services

## 🚀 Best Practices

1. **Altijd setup eerst runnen**
   ```bash
   ./00-setup.sh
   ```

2. **Voor live demo: interactive mode**
   ```bash
   ./run-full-demo.sh
   ```

3. **Voor video recording: auto mode**
   ```bash
   DEMO_MODE=auto ./run-full-demo.sh
   ```

4. **Check logs voor details**
   ```bash
   docker logs activity-api -f
   ```

## 📊 Performance Metrics

De scripts tracken automatisch:
- ⏱️ Total execution time
- 📈 Success/failure rates
- 🗄️ Database record counts
- ☁️ API response times

## 🎓 Learning Resources

Om de code te begrijpen:
1. Start met `lib/colors.sh` - formatting functies
2. Dan `lib/db.sh` - database queries
3. Dan `lib/api.sh` - API request helpers
4. Tot slot `run-full-demo.sh` - complete test flow

## 💡 Tips voor Presentaties

1. **Maximale venster** - Gebruik fullscreen terminal
2. **Grote font** - Zoom in voor leesbaarheid
3. **Dark theme** - Kleuren komen beter uit
4. **Rustig tempo** - Laat stakeholders absorber informatie
5. **Highlight key points** - Wijs belangrijke output aan

## 🎉 Credits

Gemaakt met ❤️ door het Activity App team.

Best-of-class demo scripts voor professional sprint presentations! 🏆
