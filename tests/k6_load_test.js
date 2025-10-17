import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const pageLoadTime = new Trend('page_load_time');
const ttfb = new Trend('time_to_first_byte');

// Baseline network latency adjustment (Sydney → us-central1)
const BASELINE_LATENCY = 200; // ms

// Pre-calculate threshold values
const PASS_THRESHOLD = 2000 + BASELINE_LATENCY;     // 2200ms
const MARGINAL_THRESHOLD = 3000 + BASELINE_LATENCY;  // 3200ms
const TTFB_THRESHOLD = 1000 + BASELINE_LATENCY;      // 1200ms

// Test scenario configuration
const BASELINE_VUS = 5;
const BASELINE_DURATION = '3m';
const TARGET_VUS = 20;
const TARGET_DURATION = '3m';
const PEAK_VUS = 30;
const PEAK_DURATION = '2m';

// Test configuration - OPTIMIZED FOR FASTER TESTING (~10 min total)
export const options = {
  scenarios: {
    // Scenario 1: Baseline load
    baseline_load: {
      executor: 'constant-vus',
      vus: BASELINE_VUS,
      duration: BASELINE_DURATION,
      gracefulStop: '30s',
      exec: 'averageTraffic',
      tags: { test_type: 'average' },
    },

    // Scenario 2: Target load (main test)
    target_load: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '1m', target: TARGET_VUS },
        { duration: TARGET_DURATION, target: TARGET_VUS },
        { duration: '30s', target: 10 },
      ],
      gracefulStop: '30s',
      exec: 'peakTraffic',
      tags: { test_type: 'peak' },
      startTime: '3m30s', // Run after baseline_load
    },

    // Scenario 3: Peak load (stress test)
    peak_load: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '1m', target: PEAK_VUS },
        { duration: PEAK_DURATION, target: PEAK_VUS },
        { duration: '30s', target: 0 },
      ],
      gracefulStop: '30s',
      exec: 'spikeTraffic',
      tags: { test_type: 'spike' },
      startTime: '8m', // Run after target_load
    },
  },

  thresholds: {
    // Performance requirements (based on load_testing_template.md)
    // Thresholds adjusted for baseline network latency (Sydney → us-central1)
    'http_req_duration': [`p(95)<${PASS_THRESHOLD}`], // 95% of requests < 2.2s (2s + latency)
    'http_req_duration{test_type:average}': [`p(95)<${PASS_THRESHOLD}`], // Average load
    'http_req_duration{test_type:peak}': [`p(95)<${MARGINAL_THRESHOLD}`],    // Peak load (3s + latency)
    'http_req_failed': ['rate<0.01'], // Error rate < 1%
    'page_load_time': [`p(95)<${PASS_THRESHOLD}`], // Page load < 2.2s for 95%
    'time_to_first_byte': [`p(95)<${TTFB_THRESHOLD}`], // TTFB < 700ms for 95%
  },
};

// Configuration
const WORDPRESS_URL = __ENV.WORDPRESS_URL
const THINK_TIME = 3; // Seconds between requests (simulate real user)

// Test data: actual WordPress pages only
const pages = [
  '/', // Homepage
  '/about',
  '/services',
  '/contact'
];

// Helper function: Random page selection
function getRandomPage() {
  return pages[Math.floor(Math.random() * pages.length)];
}

// Helper function: Make request and capture metrics
function makeRequest(url, tags = {}) {
  const response = http.get(url, {
    tags: tags,
    timeout: '60s',
  });

  // Check response
  const success = check(response, {
    'status is 200': (r) => r.status === 200,
    [`page load < ${PASS_THRESHOLD}ms`]: (r) => r.timings.duration < PASS_THRESHOLD,
    [`TTFB < ${TTFB_THRESHOLD}ms`]: (r) => r.timings.waiting < TTFB_THRESHOLD,
    'body size > 1KB': (r) => r.body.length > 1024,
  });

  // Record metrics
  errorRate.add(!success);
  pageLoadTime.add(response.timings.duration);
  ttfb.add(response.timings.waiting);

  return response;
}

// Scenario 1: Average traffic behavior
export function averageTraffic() {
  // Simulate typical user journey

  // 1. Browse to a random page
  const page = getRandomPage();
  makeRequest(WORDPRESS_URL + page, { page: 'browse' });
  sleep(THINK_TIME);

  // 2. Navigate to another page (50% chance)
  if (Math.random() > 0.5) {
    const nextPage = getRandomPage();
    makeRequest(WORDPRESS_URL + nextPage, { page: 'internal' });
    sleep(THINK_TIME);
  }

  // 3. Exit
  sleep(1);
}

// Scenario 2: Peak traffic behavior
export function peakTraffic() {
  // Faster browsing during peak times

  // Browse 1-2 pages quickly
  const page = getRandomPage();
  makeRequest(WORDPRESS_URL + page, { page: 'browse' });
  sleep(THINK_TIME / 2);

  if (Math.random() > 0.3) {
    const nextPage = getRandomPage();
    makeRequest(WORDPRESS_URL + nextPage, { page: 'browse' });
    sleep(THINK_TIME / 2);
  }
}

// Scenario 3: Spike traffic (e.g., viral content)
export function spikeTraffic() {
  // Many users hitting the same popular page (homepage)
  const popularPage = '/';

  makeRequest(WORDPRESS_URL + popularPage, { page: 'viral' });
  sleep(1);

  // Some users browse further
  if (Math.random() > 0.5) {
    const page = getRandomPage();
    makeRequest(WORDPRESS_URL + page, { page: 'viral-browse' });
    sleep(2);
  }
}

// Summary handler
export function handleSummary(data) {
  return {
    'summary.html': htmlReport(data),
    'summary.json': JSON.stringify(data),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

// Helper: Generate HTML report
function htmlReport(data) {
  const metrics = data.metrics;

  return `
<!DOCTYPE html>
<html>
<head>
  <title>WordPress Load Test Results</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; }
    h1 { color: #333; }
    .metric { margin: 20px 0; padding: 15px; background: #f5f5f5; border-radius: 5px; }
    .pass { color: green; font-weight: bold; }
    .fail { color: red; font-weight: bold; }
    table { border-collapse: collapse; width: 100%; margin: 20px 0; }
    th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
    th { background-color: #4CAF50; color: white; }
  </style>
</head>
<body>
  <h1>WordPress Load Test Results</h1>
  <p>Test Date: ${new Date().toISOString()}</p>
  
  <h2>Summary</h2>
  <div class="metric">
    <strong>Total Requests:</strong> ${metrics.http_reqs.values.count}<br>
    <strong>Failed Requests:</strong> ${Math.round(metrics.http_reqs.values.count * (metrics.http_req_failed.values.rate || 0))}<br>
    <strong>Error Rate:</strong> ${((metrics.http_req_failed.values.rate || 0) * 100).toFixed(2)}%<br>
    <strong>Test Duration:</strong> ${(data.state.testRunDurationMs / 1000 / 60).toFixed(2)} minutes
  </div>
  
  <h2>Performance Metrics</h2>
  <table>
    <tr>
      <th>Metric</th>
      <th>Avg</th>
      <th>Min</th>
      <th>Max</th>
      <th>P95</th>
      <th>Status</th>
    </tr>
    <tr>
      <td>Page Load Time</td>
      <td>${metrics.http_req_duration.values.avg.toFixed(2)}ms</td>
      <td>${metrics.http_req_duration.values.min.toFixed(2)}ms</td>
      <td>${metrics.http_req_duration.values.max.toFixed(2)}ms</td>
      <td>${metrics.http_req_duration.values['p(95)'].toFixed(2)}ms</td>
      <td class="${metrics.http_req_duration.values['p(95)'] < PASS_THRESHOLD ? 'pass' : 'fail'}">
        ${metrics.http_req_duration.values['p(95)'] < PASS_THRESHOLD ? `PASS (<${PASS_THRESHOLD}ms)` : `FAIL (≥${PASS_THRESHOLD}ms)`}
      </td>
    </tr>
    <tr>
      <td>Time to First Byte</td>
      <td>${metrics.http_req_waiting.values.avg.toFixed(2)}ms</td>
      <td>${metrics.http_req_waiting.values.min.toFixed(2)}ms</td>
      <td>${metrics.http_req_waiting.values.max.toFixed(2)}ms</td>
      <td>${metrics.http_req_waiting.values['p(95)'].toFixed(2)}ms</td>
      <td class="${metrics.http_req_waiting.values['p(95)'] < TTFB_THRESHOLD ? 'pass' : 'fail'}">
        ${metrics.http_req_waiting.values['p(95)'] < TTFB_THRESHOLD ? `PASS (<${TTFB_THRESHOLD}ms)` : `FAIL (≥${TTFB_THRESHOLD}ms)`}
      </td>
    </tr>
  </table>
  
  <h2>Test Scenarios</h2>
  <div class="metric">
    <strong>Baseline Load:</strong> ${BASELINE_VUS} concurrent users for ${BASELINE_DURATION}<br>
    <strong>Target Load:</strong> Ramp to ${TARGET_VUS} concurrent users, hold for ${TARGET_DURATION}<br>
    <strong>Peak Load:</strong> Ramp to ${PEAK_VUS} concurrent users, hold for ${PEAK_DURATION}
  </div>

  <h2>Acceptance Criteria (Tiny Tier)</h2>
  <div class="metric">
    <em>Note: Thresholds include ${BASELINE_LATENCY}ms baseline latency adjustment (Sydney → us-central1)</em><br><br>
    ✅ <strong>PASS:</strong> P95 response time &lt; ${PASS_THRESHOLD}ms AND error rate &lt; 1%<br>
    ⚠️ <strong>MARGINAL:</strong> P95 between ${PASS_THRESHOLD}-${MARGINAL_THRESHOLD}ms OR error rate 1-3%<br>
    ❌ <strong>FAIL:</strong> P95 &gt; ${MARGINAL_THRESHOLD}ms OR error rate &gt; 3%
  </div>
  
</body>
</html>
  `;
}

function textSummary(data, options) {
  let summary = '\n=== Load Test Summary ===\n\n';

  const metrics = data.metrics;
  const failedCount = Math.round(metrics.http_reqs.values.count * (metrics.http_req_failed.values.rate || 0));
  const errorRate = (metrics.http_req_failed.values.rate || 0) * 100;
  const p95Duration = metrics.http_req_duration.values['p(95)'];

  summary += `Total Requests: ${metrics.http_reqs.values.count}\n`;
  summary += `Failed Requests: ${failedCount}\n`;
  summary += `Error Rate: ${errorRate.toFixed(2)}%\n\n`;

  summary += `Page Load Time (95th percentile): ${p95Duration.toFixed(2)}ms\n`;
  summary += `TTFB (95th percentile): ${metrics.http_req_waiting.values['p(95)'].toFixed(2)}ms\n\n`;

  // Determine verdict based on template criteria (adjusted for baseline latency)
  let verdict = '✅ PASS';
  if (p95Duration > MARGINAL_THRESHOLD || errorRate > 3) {
    verdict = '❌ FAIL';
  } else if (p95Duration > PASS_THRESHOLD || errorRate > 1) {
    verdict = '⚠️  MARGINAL';
  }

  summary += `Performance Target: ${verdict}\n`;
  summary += `  - P95 < ${PASS_THRESHOLD}ms: ${p95Duration < PASS_THRESHOLD ? '✅' : '❌'} (${p95Duration.toFixed(2)}ms)\n`;
  summary += `  - Error rate < 1%: ${errorRate < 1 ? '✅' : '❌'} (${errorRate.toFixed(2)}%)\n`;
  summary += `\nNote: Thresholds include ${BASELINE_LATENCY}ms baseline latency (Sydney → us-central1)\n`;

  return summary;
}