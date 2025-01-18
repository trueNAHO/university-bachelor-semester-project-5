use std::collections::HashMap;
use std::fmt::{self, Display};
use std::fs::File;
use std::io::{BufRead, BufReader};
use tap::{Pipe, Tap};

use lib::Solution;

type Number = f64;

struct Station {
    count: u64,
    max: Number,
    min: Number,
    sum: Number,
}

impl Station {
    fn new(value: Number) -> Self {
        Self {
            count: 1,
            max: value,
            min: value,
            sum: value,
        }
    }

    fn update(&mut self, value: Number) {
        self.count += 1;
        self.sum += value;
        self.max = self.max.max(value);
        self.min = self.min.min(value);
    }
}

impl Display for Station {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{:.1}/{:.1}/{:.1}",
            self.min,
            self.sum / self.count as Number,
            self.max
        )
    }
}

pub struct Iteration01Base;

impl Solution for Iteration01Base {
    fn solve(input_file: &str) -> String {
        let mut stations: HashMap<String, Station> = HashMap::new();

        for line in BufReader::new(File::open(input_file).unwrap()).lines() {
            line.unwrap()
                .split_once(';')
                .unwrap()
                .pipe(|(name, number)| {
                    let number = number.parse::<Number>().unwrap();

                    stations
                        .entry(name.into())
                        .or_insert(Station::new(number))
                        .update(number);
                });
        }

        stations
            .iter()
            .collect::<Vec<_>>()
            .tap_mut(|stations| stations.sort_by_key(|station| station.0))
            .iter()
            .map(|(name, station)| format!("{}: {}", name, station))
            .collect::<Vec<_>>()
            .join(", ")
            .pipe(|string| format!("{{{}}}", string))
    }
}
