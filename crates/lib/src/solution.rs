use std::fs::read_to_string;

pub trait Solution {
    const INPUT_FILE: &str = "../../assets/input.txt";
    const OUTPUT_FILE: &str = "../../assets/output.txt";

    fn solve() -> String;

    fn test() -> bool {
        Self::solve() == read_to_string(Self::OUTPUT_FILE).unwrap().trim_end()
    }
}
