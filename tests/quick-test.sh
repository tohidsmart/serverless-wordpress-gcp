#!/bin/bash
# Quick Load Test - Test current deployment without changing infrastructure
# Usage: ./quick_test.sh <wordpress-url>

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
WORDPRESS_URL="${1:-}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="./tests/load-test-results/quick-test-${TIMESTAMP}.json"
echo $WORDPRESS_URL

# Banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║   WordPress Quick Load Test                       ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Validation
if [ -z "$WORDPRESS_URL" ]; then
    echo -e "${RED}❌ Error: WordPress URL required${NC}"
    echo "Usage: $0 <wordpress-url>"
    echo "Example: $0 https://my-site.run.app"
    exit 1
fi

if ! command -v k6 &> /dev/null; then
    echo -e "${RED}❌ Error: k6 not installed${NC}"
    exit 1
fi

# Test WordPress URL
echo -e "${BLUE}🔍 Testing WordPress URL...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WORDPRESS_URL")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    echo -e "${GREEN}   ✅ WordPress is reachable (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${YELLOW}   ⚠️  WordPress returned HTTP $HTTP_CODE${NC}"
fi

# Run load test
echo -e "${BLUE}🚀 Running load test...${NC}"
echo "   This will take approximately 10 minutes"
echo "   - Average load: 5 min"
echo "   - Peak load: 3 min"
echo "   - Spike test: 2 min"
echo ""

export WORDPRESS_URL
k6 run \
    --out json="$RESULTS_FILE" \
    --summary-export="./tests/load-test-results/summary-${TIMESTAMP}.json"  ./\tests/\k6_load_test.js

# Check if test passed
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ Load Test Complete!                          ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Results saved to:"
    echo "  - $RESULTS_FILE"
    echo "  - summary-${TIMESTAMP}.json"
    echo "  - summary.html"
    echo ""

    # Show quick summary if jq is available
    if command -v jq &> /dev/null; then
        echo -e "${BLUE}Quick Summary:${NC}"
        P95=$(jq -r '.metrics.http_req_duration.values."p(95)"' "summary-${TIMESTAMP}.json" 2>/dev/null || echo "N/A")
        ERROR_RATE=$(jq -r '.metrics.http_req_failed.values.rate * 100' "summary-${TIMESTAMP}.json" 2>/dev/null || echo "N/A")
        TOTAL_REQS=$(jq -r '.metrics.http_reqs.values.count' "summary-${TIMESTAMP}.json" 2>/dev/null || echo "N/A")

        echo "  Page Load (P95): ${P95}ms"
        echo "  Error Rate: ${ERROR_RATE}%"
        echo "  Total Requests: ${TOTAL_REQS}"

        if [ "$P95" != "N/A" ] && [ "$(echo "$P95 < 1000" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
            echo -e "  ${GREEN}✅ PASSED performance target (<1000ms)${NC}"
        else
            echo -e "  ${RED}❌ FAILED performance target (>=1000ms)${NC}"
        fi
    fi
else
    echo -e "${RED}❌ Load test failed with exit code $EXIT_CODE${NC}"
    exit $EXIT_CODE
fi
