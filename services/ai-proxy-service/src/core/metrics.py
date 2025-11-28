"""Simple metrics tracking for observability"""

import logging
import time
from datetime import datetime
from typing import Dict, List
from collections import defaultdict
from threading import Lock

logger = logging.getLogger(__name__)


class MetricsCollector:
    """In-memory metrics collector for basic observability"""

    def __init__(self):
        """Initialize metrics collector"""
        self.lock = Lock()
        self.start_time = time.time()

        # Request counters
        self.total_requests = 0
        self.successful_requests = 0
        self.failed_requests = 0
        self.requests_by_model: Dict[str, int] = defaultdict(int)

        # Token usage
        self.total_tokens_used = 0
        self.total_prompt_tokens = 0
        self.total_completion_tokens = 0

        # Billing
        self.total_cost_usd = 0.0

        # Response times (for simple stats)
        self.response_times: List[float] = []
        self.max_response_times = 1000  # Keep last 1000 response times

    def record_request(
        self,
        model: str,
        success: bool,
        prompt_tokens: int = 0,
        completion_tokens: int = 0,
        cost_usd: float = 0.0,
        response_time: float = 0.0,
    ):
        """
        Record a completed request

        Args:
            model: Model used
            success: Whether request was successful
            prompt_tokens: Number of prompt tokens
            completion_tokens: Number of completion tokens
            cost_usd: Cost in USD
            response_time: Response time in seconds
        """
        with self.lock:
            self.total_requests += 1

            if success:
                self.successful_requests += 1
                self.requests_by_model[model] += 1
                self.total_tokens_used += prompt_tokens + completion_tokens
                self.total_prompt_tokens += prompt_tokens
                self.total_completion_tokens += completion_tokens
                self.total_cost_usd += cost_usd

                # Track response time
                self.response_times.append(response_time)
                if len(self.response_times) > self.max_response_times:
                    self.response_times.pop(0)
            else:
                self.failed_requests += 1

    def get_metrics(self) -> Dict:
        """
        Get current metrics snapshot

        Returns:
            Dictionary of current metrics
        """
        with self.lock:
            uptime_seconds = time.time() - self.start_time

            # Calculate response time stats
            avg_response_time = sum(self.response_times) / len(self.response_times) if self.response_times else 0
            min_response_time = min(self.response_times) if self.response_times else 0
            max_response_time = max(self.response_times) if self.response_times else 0

            # Calculate success rate
            success_rate = (self.successful_requests / self.total_requests * 100) if self.total_requests > 0 else 0

            return {
                "service": "AI Proxy Service",
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "uptime_seconds": round(uptime_seconds, 2),
                "requests": {
                    "total": self.total_requests,
                    "successful": self.successful_requests,
                    "failed": self.failed_requests,
                    "success_rate_percent": round(success_rate, 2),
                    "by_model": dict(self.requests_by_model),
                },
                "tokens": {
                    "total": self.total_tokens_used,
                    "prompt": self.total_prompt_tokens,
                    "completion": self.total_completion_tokens,
                },
                "billing": {
                    "total_cost_usd": round(self.total_cost_usd, 6),
                },
                "performance": {
                    "avg_response_time_seconds": round(avg_response_time, 3),
                    "min_response_time_seconds": round(min_response_time, 3),
                    "max_response_time_seconds": round(max_response_time, 3),
                    "sample_size": len(self.response_times),
                },
            }

    def reset(self):
        """Reset all metrics (useful for testing)"""
        with self.lock:
            self.total_requests = 0
            self.successful_requests = 0
            self.failed_requests = 0
            self.requests_by_model.clear()
            self.total_tokens_used = 0
            self.total_prompt_tokens = 0
            self.total_completion_tokens = 0
            self.total_cost_usd = 0.0
            self.response_times.clear()


# Global metrics collector instance
metrics_collector = MetricsCollector()
