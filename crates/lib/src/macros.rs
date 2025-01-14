#[macro_export]
macro_rules! bench {
    ($type:ty) => {
        use criterion::{
            criterion_group, criterion_main, BenchmarkId, Criterion,
        };

        use lib::Solution;

        pub fn benchmark(c: &mut Criterion) {
            let mut group = c
                .benchmark_group(stringify!($type).split("::").next().unwrap());

            for size in [
                1e4 as isize,
                1e5 as isize,
                1e6 as isize,
                1e7 as isize,
                1e8 as isize,
                1e9 as isize,
            ] {
                group.bench_with_input(
                    BenchmarkId::from_parameter(size),
                    &size,
                    |b, &size| {
                        b.iter(|| <$type>::solve(&<$type>::input_file(size)))
                    },
                );
            }

            group.finish();
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
            println!("{}", <$type>::solve(&<$type>::input_file(<$type>::SIZE)));
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
