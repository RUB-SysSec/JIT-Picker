// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

public struct ProgramProducerStats {
    // Number of valid programs produced (i.e. programs that run to completion)
    private var validSamples = 0
    // Number of invalid programs produced (i.e. programs that raised an exception or timed out)
    private var invalidSamples = 0
    // Number of times this instance failed to generate/mutate a program.
    private var failures = 0
    // Total number of instructions generated by this generator/mutator.
    private var totalInstructionProduced = 0

    mutating func producedSample(addingInstructions numNewInstructions: Int) {
        totalInstructionProduced += numNewInstructions
    }

    mutating func producedValidSample() {
        validSamples += 1
    }

    mutating func producedInvalidSample() {
        invalidSamples += 1
    }

    mutating func failedToGenerateSample() {
        failures += 1
    }

    var correctnessRate: Double {
        let totalSamples = validSamples + invalidSamples
        guard totalSamples > 0 else { return 1.0 }
        return Double(validSamples) / Double(totalSamples)
    }

    var failureRate: Double {
        let totalAttempts = validSamples + invalidSamples + failures
        guard totalAttempts > 0 else { return 0.0 }
        return Double(failures) / Double(totalAttempts)
    }

    var avgNumberOfInstructionsGenerated: Double {
        let totalSamples = validSamples + invalidSamples
        guard totalSamples > 0 else { return 0.0 }
        return Double(totalInstructionProduced) / Double(totalSamples)
    }

    // TODO: Maybe also add a counter to track how often it generated new coverage?
}
