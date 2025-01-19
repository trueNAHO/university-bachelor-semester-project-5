#![feature(slice_split_once)]

use std::collections::HashMap;
use std::fmt::{self, Display};
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::str::from_utf8;
use tap::{Pipe, Tap};

use lib::Solution;

type Number = i64;

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
        let scalar = 1.0 / (10 as Number).pow(FRACTION_LENGTH as u32) as f64;

        write!(
            f,
            "{:.1}/{:.1}/{:.1}",
            self.min as f64 * scalar,
            self.sum as f64 * scalar / self.count as f64,
            self.max as f64 * scalar,
        )
    }
}

pub struct Iteration03AvoidFloatParsing;

const FRACTION_LENGTH: usize = 1;

impl Solution for Iteration03AvoidFloatParsing {
    fn solve(input_file: &str) -> String {
        let mut buffer = Vec::<u8>::new();
        let mut reader = BufReader::new(File::open(input_file).unwrap());
        let mut stations: HashMap<Vec<u8>, Station> = HashMap::new();

        while reader.read_until(b'\n', &mut buffer).unwrap() != 0 {
            buffer.split_once(|&byte| byte == b';').unwrap().pipe(
                |(name, mut number)| {
                    let negative = if number[0] == b'-' {
                        number = &number[1..];
                        true
                    } else {
                        false
                    };

                    let number = number[..number.len() - 1]
                        .split_once(|&byte| byte == b'.')
                        .unwrap_or((number, &[0; FRACTION_LENGTH]))
                        .tap(|(_, fraction)| {
                            assert_eq!(fraction.len(), FRACTION_LENGTH)
                        })
                        .pipe(|(integer, fraction)| {
                            integer.iter().chain(fraction)
                        })
                        .rev()
                        .enumerate()
                        .map(|(i, &byte)| {
                            (if negative { -1 } else { 1 })
                                * (byte - b'0') as Number
                                * (10 as Number).pow(i as u32)
                        })
                        .sum();

                    stations
                        .entry(name.into())
                        .or_insert(Station::new(number))
                        .update(number);
                },
            );

            buffer.clear();
        }

        stations
            .iter()
            .collect::<Vec<_>>()
            .tap_mut(|stations| stations.sort_by_key(|station| station.0))
            .iter()
            .map(|(name, station)| {
                format!("{}: {}", from_utf8(name).unwrap(), station)
            })
            .collect::<Vec<_>>()
            .join(", ")
            .pipe(|string| format!("{{{}}}", string))
    }
}
