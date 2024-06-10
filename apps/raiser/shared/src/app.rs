use chrono::{serde::ts_milliseconds_option::deserialize as ts_milliseconds_option, DateTime, Utc};
use crux_core::render::Render;
use crux_http::Http;
use serde::{Deserialize, Serialize};
use url::Url;

use crate::capabilities::delay::Delay;

const API_URL: &str = "https://crux-counter.fly.dev";

#[derive(Default, Serialize)]
pub struct Model {
	count: Count,
}

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq, Eq)]
pub struct Count {
	value: isize,
	#[serde(deserialize_with = "ts_milliseconds_option")]
	updated_at: Option<DateTime<Utc>>,
}

#[derive(Serialize, Deserialize, Debug, Clone, Default)]
pub struct ViewModel {
	pub text: String,
	pub confirmed: bool,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub enum Event {
	// events from the shell
	Get,
	Increment,
	DoIncrement(usize),
	Decrement,
	// events local to the core
	#[serde(skip)]
	Set(crux_http::Result<crux_http::Response<Count>>),
	#[serde(skip)]
	Update(Count),
}

#[cfg_attr(feature = "typegen", derive(crux_core::macros::Export))]
#[derive(crux_core::macros::Effect)]
pub struct Capabilities {
	pub render: Render<Event>,
	pub http: Http<Event>,
	pub delay: Delay<Event>,
}

#[derive(Default)]
pub struct App;

impl crux_core::App for App {
	type Model = Model;
	type Event = Event;
	type ViewModel = ViewModel;
	type Capabilities = Capabilities;

	fn update(&self, msg: Self::Event, model: &mut Self::Model, caps: &Self::Capabilities) {
		match msg {
			Event::Get => {
				caps.http.get(API_URL).expect_json().send(Event::Set);
			}
			Event::Set(Ok(mut response)) => {
				let count = response.take_body().unwrap();
				self.update(Event::Update(count), model, caps);
			}
			Event::Set(Err(e)) => {
				panic!("Oh no something went wrong: {e:?}");
			}
			Event::Update(count) => {
				model.count = count;
				caps.render.render();
			}
			Event::Increment => caps.delay.random(200, 800, Event::DoIncrement),
			Event::DoIncrement(_millis) => {
				model.count = Count {
					value: model.count.value + 1,
					updated_at: None,
				};
				caps.render.render();

				let base = Url::parse(API_URL).unwrap();
				let url = base.join("/inc").unwrap();
				caps.http.post(url).expect_json().send(Event::Set);
			}
			Event::Decrement => {
				model.count = Count {
					value: model.count.value - 1,
					updated_at: None,
				};
				caps.render.render();

				let base = Url::parse(API_URL).unwrap();
				let url = base.join("/dec").unwrap();
				caps.http.post(url).expect_json().send(Event::Set);
			}
		}
	}

	fn view(&self, model: &Self::Model) -> Self::ViewModel {
		let suffix = match model.count.updated_at {
			None => " (pending)".to_string(),
			Some(d) => format!(" ({d})"),
		};

		Self::ViewModel {
			text: model.count.value.to_string() + &suffix,
			confirmed: model.count.updated_at.is_some(),
		}
	}
}
