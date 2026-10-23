import Darwin

/// The clock for key events and ticks alike. KasaneCore only compares differences.
func uptime() -> Duration {
    .nanoseconds(clock_gettime_nsec_np(CLOCK_UPTIME_RAW))
}
