package main

import "testing"

func TestAddition(t *testing.T) {
    result := 2 + 2
    if result != 4 {
        t.Errorf("Expected 4, got %d", result)
    }
}

func TestSubtraction(t *testing.T) {
    result := 5 - 3
    if result != 2 {
        t.Errorf("Expected 2, got %d", result)
    }
}

func BenchmarkAddition(b *testing.B) {
    for i := 0; i < b.N; i++ {
        _ = 2 + 2
    }
}