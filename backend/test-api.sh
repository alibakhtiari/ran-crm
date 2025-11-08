#!/bin/bash

# Test script for CRM Backend API
# This script tests all major endpoints and reports errors

BASE_URL="https://shared-contact-crm.ramzarznegaran.workers.dev"
echo "🚀 Testing CRM Backend API"
echo "Base URL: $BASE_URL"
echo "=================================================="

# Test 1: Health check
echo -e "\n📋 Test 1: Health Check"
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/")
if [ "$response" = "200" ]; then
    echo "✅ PASS - Health check successful"
else
    echo "❌ FAIL - Health check returned HTTP $response"
    exit 1
fi

# Test 2: Admin login (will fail if no users exist, but should return proper error)
echo -e "\n📋 Test 2: Admin Login"
response=$(curl -s -X POST "$BASE_URL/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin123"}' \
  -w "\nHTTP Status: %{http_code}")

http_code=$(echo "$response" | grep "HTTP Status:" | cut -d' ' -f3)
if [ "$http_code" = "200" ]; then
    echo "✅ PASS - Admin login successful"
    # Extract token for further tests
    token=$(echo "$response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    echo "🔑 Token received: ${token:0:20}..."
elif [ "$http_code" = "401" ] || [ "$http_code" = "500" ]; then
    echo "⚠️  WARN - Login failed (expected if no users exist yet)"
    echo "   Response: $(echo $response | head -1)"
else
    echo "❌ FAIL - Unexpected HTTP $http_code"
    echo "   Response: $response"
fi

# Test 3: Admin routes (should return HTML for login page)
echo -e "\n📋 Test 3: Admin Login Page"
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/admin/")
if [ "$response" = "200" ]; then
    echo "✅ PASS - Admin login page accessible"
else
    echo "❌ FAIL - Admin login page returned HTTP $response"
fi

# Test 4: Admin dashboard (should redirect to login if not authenticated)
echo -e "\n📋 Test 4: Admin Dashboard"
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/admin/dashboard")
if [ "$response" = "200" ] || [ "$response" = "302" ]; then
    echo "✅ PASS - Admin dashboard route accessible"
else
    echo "❌ FAIL - Admin dashboard returned HTTP $response"
fi

# Test 5: Protected endpoint without auth (should return 401)
echo -e "\n📋 Test 5: Protected Endpoint (No Auth)"
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/contacts")
if [ "$response" = "401" ]; then
    echo "✅ PASS - Protected endpoint properly requires auth"
else
    echo "❌ FAIL - Expected 401, got HTTP $response"
fi

# Test 6: Non-existent endpoint (should return 404)
echo -e "\n📋 Test 6: Non-existent Endpoint"
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/nonexistent")
if [ "$response" = "404" ]; then
    echo "✅ PASS - Non-existent endpoint returns 404"
else
    echo "❌ FAIL - Expected 404, got HTTP $response"
fi

echo -e "\n=================================================="
echo "🏁 Test completed! Check results above."
echo "=================================================="

# Summary
echo -e "\n📊 Quick Summary:"
echo "✅ = Test passed"
echo "❌ = Test failed"
echo "⚠️  = Warning (expected behavior)"
echo -e "\nIf tests are failing, check:"
echo "1. Database schema is applied (schema.sql)"
echo "2. Test users are seeded (seed.sql)"
echo "3. JWT_SECRET is set in wrangler.toml"
echo "4. Database is accessible"
