#[macro_export]
macro_rules! bench {
    ($type:ty) => {
        use criterion::{criterion_group, criterion_main, Criterion};
        use lib::Solution;

        pub fn benchmark(c: &mut Criterion) {
            c.bench_function(
                stringify!($type).split("::").next().unwrap(),
                |b| b.iter(<$type>::solve),
            );
        }

        criterion_group!(benches, benchmark);
        criterion_main!(benches);
    };
}

#[macro_export]
macro_rules! main {
    ($type:ty) => {
        use lib::Solution;
        use $type;

        fn main() {
            println!("{}", <$type>::solve());
        }
    };
}

#[macro_export]
macro_rules! test {
    ($type:ty) => {
        use lib::Solution;

        #[test]
        fn solve() {
            assert!(<$type>::test())
        }
    };
}
