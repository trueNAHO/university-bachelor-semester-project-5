use std::fs::read_to_string;

use lib::Solution;

pub struct Iteration01Base;

impl Solution for Iteration01Base {
    fn solve() -> String {
        read_to_string(Self::INPUT_FILE)
            .unwrap()
            .trim_end()
            .to_string()
    }
}
