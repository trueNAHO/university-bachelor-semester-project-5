use std::fs::read_to_string;

use lib::Solution;

pub struct Iteration02Base;

impl Solution for Iteration02Base {
    fn solve(input_file: &str) -> String {
        read_to_string(input_file).unwrap().trim_end().to_string()
    }
}
