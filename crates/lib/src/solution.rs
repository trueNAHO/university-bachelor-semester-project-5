use std::fs::read_to_string;

pub trait Solution {
    const SIZE: isize = 1e9 as isize;

    fn input_file(size: isize) -> String {
        format!("../../assets/input-{}.txt", size)
    }

    fn output_file(size: isize) -> String {
        format!("../../assets/output-{}.txt", size)
    }

    fn solve(input_file: &str) -> String;

    fn test() -> bool {
        Self::solve(&Self::input_file(Self::SIZE))
            == read_to_string(Self::output_file(Self::SIZE))
                .unwrap()
                .trim_end()
    }
}
